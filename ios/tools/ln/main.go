// Draws true 3D scenes as line art, frame by frame, for widgets.
//
//	cd ios/tools/ln && go run . [scene ...]
//
// Each scene is a function of time that repeats. It is rendered with ln
// (github.com/fogleman/ln, MIT), which draws 3D lines and leaves out
// whatever a solid hides, and written to frames/<name>.json in the form
// tools/hairline/capture.mjs writes: a list of frames, each a list of SVG
// shapes on a stage 400 wide and 320 tall. tools/make_motion_fonts.py turns
// those into the fonts a widget plays at eight frames a second.
//
// The globe's coastline is Natural Earth's (public domain), which
// tools/make_river_maps.py and this program keep in tools/.cache.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/fogleman/ln/ln"
)

const (
	stageW = 400.0
	stageH = 320.0
	fps    = 8
)

// The widget's palette, as in tools/hairline/capture.mjs.
var palette = map[string]string{"plate": "#0c0d11", "hi": "#ffffff", "edge": "#b4b8c4", "mid": "#6c7180", "lo": "#353842"}

type shape struct {
	Tag    string `json:"tag"`
	D      string `json:"d"`
	Stroke string `json:"stroke"`
}

// A layer is some lines in space and the tone they are drawn in.
type layer struct {
	lines ln.Paths
	tone  string
}

// A view is one frame: the solids that hide what is behind them, the lines
// to draw, and where the camera is.
type view struct {
	solids  []ln.Shape
	layers  []layer
	eye     ln.Vector
	center  ln.Vector
	fovy    float64
	detail  float64 // how finely lines are cut to test what is hidden
	offsetY float64 // moves the picture down the stage, in stage units
}

func number(v float64) string {
	return strconv.FormatFloat(math.Round(v*10)/10, 'f', -1, 64)
}

func (v view) render() []shape {
	scene := ln.Scene{}
	for _, solid := range v.solids {
		scene.Add(solid)
	}
	scene.Compile()
	matrix := ln.LookAt(v.eye, v.center, ln.Vector{X: 0, Y: 0, Z: 1}).Perspective(v.fovy, stageW/stageH, 0.1, 100)
	var out []shape
	for _, l := range v.layers {
		visible := l.lines.Chop(v.detail).Filter(&ln.ClipFilter{Matrix: matrix, Eye: v.eye, Scene: &scene})
		var d strings.Builder
		for _, path := range visible {
			var flat ln.Path
			for _, p := range path {
				flat = append(flat, ln.Vector{X: (p.X + 1) * stageW / 2, Y: (1-p.Y)*stageH/2 + v.offsetY})
			}
			flat = flat.Simplify(0.14)
			if len(flat) < 2 || (len(flat) == 2 && flat[0].Distance(flat[1]) < 0.4) {
				continue
			}
			for i, p := range flat {
				command := "L"
				if i == 0 {
					command = "M"
				}
				d.WriteString(command + number(p.X) + " " + number(p.Y))
			}
		}
		if d.Len() > 0 {
			out = append(out, shape{"path", d.String(), palette[l.tone]})
		}
	}
	return out
}

// ---- globe

const coastURL = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_coastline.geojson"

// The world's coastlines as lines on a sphere of radius 1, without the
// smallest islands and with fewer points than the map has.
func coastlines() ln.Paths {
	file := filepath.Join("..", ".cache", "ne_110m_coastline.geojson")
	if _, err := os.Stat(file); err != nil {
		response, err := http.Get(coastURL)
		check(err)
		defer response.Body.Close()
		data, err := io.ReadAll(response.Body)
		check(err)
		check(os.MkdirAll(filepath.Dir(file), 0o755))
		check(os.WriteFile(file, data, 0o644))
	}
	data, err := os.ReadFile(file)
	check(err)
	var collection struct {
		Features []struct {
			Geometry struct {
				Type        string          `json:"type"`
				Coordinates json.RawMessage `json:"coordinates"`
			} `json:"geometry"`
		} `json:"features"`
	}
	check(json.Unmarshal(data, &collection))
	var result ln.Paths
	for _, feature := range collection.Features {
		var lines [][][]float64
		if feature.Geometry.Type == "LineString" {
			var line [][]float64
			check(json.Unmarshal(feature.Geometry.Coordinates, &line))
			lines = append(lines, line)
		} else {
			check(json.Unmarshal(feature.Geometry.Coordinates, &lines))
		}
		for _, line := range lines {
			var flat ln.Path
			box := [4]float64{180, 90, -180, -90}
			for _, p := range line {
				flat = append(flat, ln.Vector{X: p[0], Y: p[1]})
				box = [4]float64{math.Min(box[0], p[0]), math.Min(box[1], p[1]), math.Max(box[2], p[0]), math.Max(box[3], p[1])}
			}
			if math.Hypot(box[2]-box[0], box[3]-box[1]) < 4.5 {
				continue
			}
			var path ln.Path
			for _, p := range flat.Simplify(0.4) {
				path = append(path, ln.LatLngToXYZ(p.Y, p.X, 1))
			}
			result = append(result, path)
		}
	}
	return result
}

// The Earth turning once in the loop, leaning on its axis, with a grid of
// meridians and parallels under the coastlines and its edge drawn bright.
func globe() (seconds int, at func(t float64) view) {
	coast := coastlines()
	var grid ln.Paths
	for lng := 0; lng < 360; lng += 30 {
		var path ln.Path
		for lat := -80.0; lat <= 80; lat += 2 {
			path = append(path, ln.LatLngToXYZ(lat, float64(lng), 1))
		}
		grid = append(grid, path)
	}
	for lat := -60; lat <= 60; lat += 30 {
		var path ln.Path
		for lng := 0.0; lng <= 360; lng += 2 {
			path = append(path, ln.LatLngToXYZ(float64(lat), lng, 1))
		}
		grid = append(grid, path)
	}
	axis := ln.Paths{{ln.Vector{Z: -1.32}, ln.Vector{Z: -1}}, {ln.Vector{Z: 1}, ln.Vector{Z: 1.32}}}
	eye := ln.Vector{X: 4.6, Y: 0, Z: 1.1}
	lean := ln.Rotate(ln.Vector{X: 1, Y: 0, Z: 0}, ln.Radians(-20))
	return 30, func(t float64) view {
		turn := ln.Rotate(ln.Vector{X: 0, Y: 0, Z: 1}, ln.Radians(360*t)).Rotate(ln.Vector{X: 1, Y: 0, Z: 0}, ln.Radians(-20))
		edge := ln.NewOutlineSphere(eye, ln.Vector{X: 0, Y: 0, Z: 1}, ln.Vector{}, 1).Paths()
		return view{
			solids: []ln.Shape{ln.NewSphere(ln.Vector{}, 1)},
			layers: []layer{
				{grid.Transform(turn), "lo"},
				{axis.Transform(lean), "mid"},
				{coast.Transform(turn), "edge"},
				{edge, "hi"},
			},
			eye: eye, fovy: 30, detail: 0.012, offsetY: 6,
		}
	}
}

// ---- ripples

// Rings spreading from the middle of a square of water, drawn as lines
// across it, each hiding the ones behind where it rises.
func ripples() (seconds int, at func(t float64) view) {
	const half = 2.0
	height := func(t float64) func(x, y float64) float64 {
		return func(x, y float64) float64 {
			r := math.Hypot(x, y)
			return 0.34 * math.Cos(2*math.Pi*(r*0.95-t)) / (1 + 0.55*r*r)
		}
	}
	eye := ln.Vector{X: 0, Y: -5.6, Z: 3.3}
	return 4, func(t float64) view {
		f := height(t)
		var lines ln.Paths
		for row := 0; row <= 26; row++ {
			y := -half + 2*half*float64(row)/26
			var path ln.Path
			for x := -half; x <= half+1e-9; x += 0.02 {
				path = append(path, ln.Vector{X: x, Y: y, Z: f(x, y)})
			}
			lines = append(lines, path)
		}
		// The line through the middle carries the highlight.
		return view{
			solids: []ln.Shape{ln.NewFunction(f, ln.Box{Min: ln.Vector{X: -half, Y: -half, Z: -1}, Max: ln.Vector{X: half, Y: half, Z: 1}}, ln.Below)},
			layers: []layer{{append(lines[:13:13], lines[14:]...), "edge"}, {lines[13:14], "hi"}},
			eye:    eye, center: ln.Vector{Z: -0.1}, fovy: 45, detail: 0.02, offsetY: 2,
		}
	}
}

// ---- sculpture

// A cube rounded by a sphere and drilled through on all three axes, turning
// on a stand. It looks the same after a quarter turn, so that is the loop.
func sculpture() (seconds int, at func(t float64) view) {
	form := ln.NewDifference(
		ln.NewIntersection(
			ln.NewSphere(ln.Vector{}, 1),
			ln.NewCube(ln.Vector{X: -0.8, Y: -0.8, Z: -0.8}, ln.Vector{X: 0.8, Y: 0.8, Z: 0.8}),
		),
		ln.NewCylinder(0.4, -2, 2),
		ln.NewTransformedShape(ln.NewCylinder(0.4, -2, 2), ln.Rotate(ln.Vector{X: 1, Y: 0, Z: 0}, ln.Radians(90))),
		ln.NewTransformedShape(ln.NewCylinder(0.4, -2, 2), ln.Rotate(ln.Vector{X: 0, Y: 1, Z: 0}, ln.Radians(90))),
	)
	// Where the cube's faces cut the sphere, and where the holes come out
	// of them: circles ln does not draw by itself.
	circle := func(radius float64, toFace ln.Matrix) ln.Path {
		var path ln.Path
		for a := 0.0; a <= 360; a += 3 {
			path = append(path, toFace.MulPosition(ln.Vector{X: radius * math.Cos(ln.Radians(a)), Y: radius * math.Sin(ln.Radians(a)), Z: 0.8}))
		}
		return path
	}
	var rims ln.Paths
	for _, toFace := range []ln.Matrix{
		ln.Identity(),
		ln.Rotate(ln.Vector{X: 1}, ln.Radians(180)),
		ln.Rotate(ln.Vector{X: 1}, ln.Radians(90)), ln.Rotate(ln.Vector{X: 1}, ln.Radians(-90)),
		ln.Rotate(ln.Vector{Y: 1}, ln.Radians(90)), ln.Rotate(ln.Vector{Y: 1}, ln.Radians(-90)),
	} {
		rims = append(rims, circle(0.6, toFace), circle(0.4, toFace))
	}
	eye := ln.Vector{X: 0, Y: -6, Z: 2.4}
	return 6, func(t float64) view {
		turn := ln.Rotate(ln.Vector{X: 0, Y: 0, Z: 1}, ln.Radians(90*t))
		turned := ln.NewTransformedShape(form, turn)
		return view{
			solids: []ln.Shape{turned},
			layers: []layer{{turned.Paths(), "mid"}, {rims.Transform(turn), "edge"}},
			eye:    eye, fovy: 24, detail: 0.01, offsetY: 0,
		}
	}
}

func check(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "ln:", err)
		os.Exit(1)
	}
}

func main() {
	scenes := map[string]func() (int, func(float64) view){"globe": globe, "ripples": ripples, "sculpture": sculpture}
	names := os.Args[1:]
	if len(names) == 0 {
		names = []string{"globe", "ripples", "sculpture"}
	}
	check(os.MkdirAll("frames", 0o755))
	for _, name := range names {
		build, ok := scenes[name]
		if !ok {
			check(fmt.Errorf("no scene called %q", name))
		}
		seconds, at := build()
		count := seconds * fps
		frames := make([][]shape, count)
		heaviest := 0
		for k := 0; k < count; k++ {
			frames[k] = at(float64(k) / float64(count)).render()
			size := 0
			for _, s := range frames[k] {
				size += len(s.D)
			}
			heaviest = max(heaviest, size)
		}
		data, err := json.Marshal(map[string]any{"name": name, "seconds": seconds, "fps": fps, "palette": palette, "frames": frames})
		check(err)
		check(os.WriteFile(filepath.Join("frames", name+".json"), data, 0o644))
		fmt.Printf("%s  %d s, %d frames, %.1f KB a frame at most\n", name, seconds, count, float64(heaviest)/1024)
	}
}
