import haxe.io.Bytes;
import hxColorToolkit.spaces.HSL;
using Lambda;

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

typedef Point = Pair<Int, Int>;

/** Generates a nice color palette to use in the animation */
function generatePalette(): Bytes {
    final pal = Bytes.alloc(256 * 3);

    for (index in 0...256) {
        final color = new HSL(300 - index * 300 / 256, 75, 50).toRGB();
        pal.set(index * 3 + 0, Std.int(color.red));
        pal.set(index * 3 + 1, Std.int(color.green));
        pal.set(index * 3 + 2, Std.int(color.blue));
    }
    // 0 should be black
    pal.set(0, 0);
    pal.set(1, 0);
    pal.set(2, 0);

    return pal;
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
    public function runDLA(startPoints: Iterable<Point>, target: Float) {
        for (pt in startPoints)
            setPixelAt(pt.x, pt.y, true);
        var pixelsFilled = startPoints.count();

        if (target >= 1.0)
            throw "The algorithm will hang, set the target < 1";
        final pixelsToFill = Math.floor(edgeLen * edgeLen * target);

        anim.init(edgeLen, edgeLen, pixelsToFill+1, ColIndexed, generatePalette());
        addAnimFrame();

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

            if (pixelsFilled % 64 == 0)
                addAnimFrame();

            pixelsFilled++;
            trace('$pixelsFilled/$pixelsToFill');
        }
    }

    private function findFreePixel(): Point {
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
    private function movePixelRandomly(px: Point) {
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
    private function doesPixelNeighbor(px: Point): Bool {
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
