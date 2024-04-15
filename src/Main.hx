import haxe.exceptions.PosException;
import hxColorToolkit.spaces.ARGB;
import mcli.CommandLine;
import mcli.Dispatch;
import haxe.Json;
import sys.io.File;
import haxe.io.Bytes;
import format.png.Data as PngData;
import format.png.Tools as PngTools;
import format.png.Writer as PngWriter;
import format.png.Reader as PngReader;
import hxColorToolkit.spaces.HSL;
import Grid;

class MainConfig extends CommandLine {
    /**
        @alias g
    **/
    public var gridSize: Int = 128;
    public var targetFill: Float = 0.2;
    public var startJson: Null<String> = null;
    public var startPng: Null<String> = null;

    public function runDefault(outputPath: String) {
        final f = File.write(outputPath);
        final g = new Grid(gridSize);

        final startingPts: Iterable<Point> = 
            if (startJson != null)
                parseStartJson()
            else if (startPng != null)
                parseStartPng()
            else
                [new Pair(Std.int(gridSize/2), Std.int(gridSize/2))];
        g.runDLA(startingPts, targetFill);

        new PngWriter(f).write(g.anim.finalize());
        f.close();        
    }

    private function parseStartJson(): Array<Point> {
        final jsonPts: Array<Array<Int>> = Json.parse(startJson);
        return jsonPts.map((it) -> new Point(it[0], it[1]));
    }

    private function parseStartPng(): List<Point> {
        final f = File.read(startPng);
        final png = new PngReader(f).read();
        f.close();
        final head = PngTools.getHeader(png);
        if (head.width != gridSize || head.height != gridSize)
            throw "Please adjust the starting image size to the grid size";

        final data = PngTools.extract32(png);
        final startPts = new List();
        for (y in 0...head.height) {
            for (x in 0...head.width) {
                final pixel = data.getInt32(4*(y*head.width + x));
                if (pixel != 0 && pixel != 0xff000000) {
                    startPts.add(new Point(x, y));
                }
            }
        }
        return startPts;
    }
}

class Main {
    static function main() {
        new Dispatch(Sys.args()).dispatch(new MainConfig());
    }
}
