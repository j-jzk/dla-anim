import sys.io.File;
import haxe.io.Bytes;
import format.png.Data as PngData;
import format.png.Writer as PngWriter;
import format.png.Tools as PngTools;

class Pair<A, B> {
    public var x: A;
    public var y: B;

    public function new(x: A, y: B) {
        this.x = x;
        this.y = y;
    }

    public function toString(): String
        return '[$x, $y]';
}

class Grid {
    public var grid: Bytes;
    public var edgeLen: Int;

    public function new(edgeLen: Int) {
        grid = Bytes.alloc(edgeLen * edgeLen);
        grid.fill(0, edgeLen*edgeLen, 0); // zero
        this.edgeLen = edgeLen;
    }

    function isPixelAt(x: Int, y: Int): Bool {
        return grid.get(x + y*edgeLen) != 0;
    }
    function setPixelAt(x: Int, y: Int, val: Bool) {
        grid.set(x + y*edgeLen, val ? 255 : 0);
    }

     /**
     * @param startX position of the starting pixel
     * @param startY position of the starting pixel
     * @param target the target ratio of filled pixels.
     */
    public function runDLA(startX: Int, startY: Int, target: Float) {
        setPixelAt(startX, startY, true);
        var pixelsFilled = 1;

        if (target >= 1.0)
            throw "The algorithm will hang, set the target < 1";
        final pixelsToFill = Math.floor(edgeLen * edgeLen * target);

        while (pixelsFilled < pixelsToFill) {
            final pixel = findFreePixel();
            // trace('found free px: $pixel');
            while (!doesPixelNeighbor(pixel)) {
                movePixelRandomly(pixel);
                // trace('movin: $pixel');
            }

            setPixelAt(pixel.x, pixel.y, true);
            pixelsFilled++;
            trace('$pixelsFilled/$pixelsToFill');
        }
    }

    private function findFreePixel(): Pair<Int, Int> {
        var x: Int;
        var y: Int;
        do {
            x = Std.random(edgeLen);
            y = Std.random(edgeLen);
        } while (isPixelAt(x, y));

        return new Pair(x, y);
    }

    /**
     * Moves the specified pixel randomly (in place), respecting the edges
     */
    private function movePixelRandomly(px: Pair<Int, Int>) {
        switch (Std.random(4)) {
            // the movement at the edges isn't so uniformly random but wahtever
            case 0:
                if (px.x > 0) px.x--;
            case 1:
                if (px.x < edgeLen-1) px.x++;
            case 2:
                if (px.y > 0) px.y--;
            case 3:
                if (px.y < edgeLen-1) px.y++;    
        }
    }

    /** Returns true if the spec. pixel is adjacent to any filled pixels */
    private function doesPixelNeighbor(px: Pair<Int, Int>): Bool {
        if (px.x > 0 && isPixelAt(px.x - 1, px.y))
            return true;
        if (px.y > 0 && isPixelAt(px.x, px.y - 1))
            return true;
        if (px.x < edgeLen-1 && isPixelAt(px.x + 1, px.y))
            return true;
        if (px.y < edgeLen-1 && isPixelAt(px.x, px.y + 1))
            return true;
        return false;
    }
}

function exportToPng(g: Grid): PngData {
    // final pngBytes = Bytes.alloc(g.grid.length * 4);
    // for (i in 0..g.grid.length) {
    //     if (Bytes.fastGet(g.grid, i) != 0)
    //         pngBytes.setInt32(i*4, 0xffffffff)
    //     else
    //         pngBytes.setInt32(i*4, 0x000000ff);
    // }
    return PngTools.buildGrey(g.edgeLen, g.edgeLen, g.grid);
}

class Main {
    static function main() {
        trace("opening the file");
        final f = File.write(Sys.args()[0]);
        trace("alloc grid");
        final g = new Grid(128);
        trace("lets go");
        g.runDLA(63, 63, 0.25);

        new PngWriter(f).write(exportToPng(g));
        f.close();        
    }
}
