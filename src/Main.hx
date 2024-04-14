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
    public var anim = new Apng();

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
    function setPixelValue(x: Int, y: Int, val: Int) {
        grid.set(x + y*edgeLen, val);
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

        anim.init(edgeLen, edgeLen, pixelsToFill+1);
        addAnimPixel(startX, startY);

        while (pixelsFilled < pixelsToFill) {
            final pixel = findFreePixel();
            while (!doesPixelNeighbor(pixel)) {
                movePixelRandomly(pixel);
            }

            setPixelValue(
                pixel.x,
                pixel.y,
                Math.ceil(255 * (1 - pixelsFilled/pixelsToFill)),
            );

            if (pixelsFilled % 15 == 0)
                addAnimFrame();

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

    private final oneWhitePixel = Bytes.ofHex("ff");
    private function addAnimPixel(x: Int, y: Int) {
        anim.addFrame(x, y, 1, 1, 1, oneWhitePixel);
    }

    private function addAnimFrame() {
        anim.addFrame(0, 0, edgeLen, edgeLen, 1, grid, 9);
    }
}

// function exportToPng(g: Grid): PngData {
//     return PngTools.buildGrey(g.edgeLen, g.edgeLen, g.grid);
// }

class Main {
    static function main() {
        final f = File.write(Sys.args()[0]);
        final g = new Grid(128);
        g.runDLA(2, 2, 0.25);

        new PngWriter(f).write(g.anim.finalize());
        f.close();        
    }
}
