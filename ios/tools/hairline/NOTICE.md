# Third-party code used by these tools

## Hairline

The `hairline-create` skill in `.claude/skills/hairline-create` (its engine `kernel.js`,
its page `bench.html` and its scripts) is by Lucas Marques,
https://github.com/lucasmarkes/hairline. It was installed unchanged with
`npx skills add lucasmarkes/hairline`. The virtual clock in `capture.mjs` is
adapted from the one in that project's tests. Its license:

    MIT License
    
    Copyright (c) 2026 Lucas Marques
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

## ln

`tools/ln` uses Michael Fogleman's ln, https://github.com/fogleman/ln, as a Go
module; none of it is copied here. It is MIT licensed, Copyright (C) 2016
Michael Fogleman.
