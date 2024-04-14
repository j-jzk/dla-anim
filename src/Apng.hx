import haxe.io.BytesOutput;
import haxe.io.Bytes;
import format.png.Data;
using BytesTools;

enum abstract FctlDispose(Int) to Int {
    /**
     * No disposal is done on this frame before rendering the next; the contents of the output buffer are left as is.
     */
    var None = 0;
    /**
     * The frame's region of the output buffer is to be cleared to fully transparent black before rendering the next frame.
     */
    var Background = 1;
    /**
     * The frame's region of the output buffer is to be reverted to the previous contents before rendering the next frame.
     */
    var Previous = 2;
}

enum abstract FctlBlend(Int) to Int {
    /**
     * All color components of the frame, including alpha, overwrite the current contents of the frame's output buffer region.
     */
    var Source = 0;
    /**
     * The frame should be composited onto the output buffer based on its alpha, using a simple OVER operation as described in the "Alpha Channel Processing" section of the PNG specification.
     */
    var Over = 0;
}

typedef FrameControl = {
    seqNum: Int,
    width: Int,
    height: Int,
    xOffset: Int,
    yOffset: Int,
    delayNum: Int,
    delayDen: Int,
    disposeOp: FctlDispose,
    blendOp: FctlBlend,
};

/**
 * Basic APNG tools, tailored to the needs of this project
 */
class Apng {
    public var chunks: List<Chunk> = new List();

    public function new() {}
    // public function new() {
    //     chunks = new List();
    // }

    public function init(width: Int, height: Int, numFrames: Int) {
        chunks.add(CHeader({
            width: width,
            height: height,
            interlaced: false,
            colbits: 8,
            color: ColGrey(false),
        }));
        chunks.add(generateActl(numFrames, 1));

        // add a black frame
        var black = Bytes.alloc(width * height);
        black.fill(0, black.length, 0);
        addIdat(width, height, black);
        addFrame(0, 0, width, height, 1, black, 9);
    }

    private var seqNum = 0;
    public function addFrame(x: Int, y: Int, width: Int, height: Int, durationMs: Int, data: Bytes, compLvl = 0) {
        chunks.add(generateFctl({
            seqNum: seqNum++,
            width: width,
            height: height,
            xOffset: x,
            yOffset: y,
            delayNum: durationMs,
            delayDen: 1000,
            disposeOp: None,
            blendOp: Source,
        }));

        // stolen from format.png.tools.buildGrey()
        // TODO: make this generic for any color scheme
        var fdat = haxe.io.Bytes.alloc(width * height + height);
        var w = 0, r = 0;
		for( y in 0...height ) {
			fdat.set(w++,0); // no filter for this scanline
			for( x in 0...width )
				fdat.set(w++,data.get(r++));
		}
        // fdat.setInt32BE(0, seqNum++);
        chunks.add(generateFdat(seqNum++, fdat, compLvl));
    }

    public function finalize(): Data {
        chunks.add(CEnd);
        return chunks;
    }

    // LOW LEVEL CHUNK GENERATION
    /**
     * Generates an Animation Control chunk
     */
    public function generateActl(numFrames: Int, numPlays: Int): Chunk {
        final data = new BytesOutput();
        data.bigEndian = true;
        data.writeInt32(numFrames);
        data.writeInt32(numPlays);
        return CUnknown("acTL", data.getBytes());
    }

    /**
     * Generates a Frame Control chunk
     */
    public function generateFctl(content: FrameControl): Chunk {
        final data = new BytesOutput();
        data.bigEndian = true;
        data.writeInt32(content.seqNum);
        data.writeInt32(content.width);
        data.writeInt32(content.height);
        data.writeInt32(content.xOffset);
        data.writeInt32(content.yOffset);
        data.writeUInt16(content.delayNum);
        data.writeUInt16(content.delayDen);
        data.writeByte(content.disposeOp);
        data.writeByte(content.blendOp);
        return CUnknown("fcTL", data.getBytes());
    }

    /**
     * Generates a Frame Data chunk
     */
    public function generateFdat(seqNum: Int, data: Bytes, compLvl = 0): Chunk {    
        final compressed = format.tools.Deflate.run(data, compLvl);
        final frameData = Bytes.alloc(compressed.length + 4);
        frameData.blit(4, compressed, 0, compressed.length);
    
        frameData.setInt32BE(0, seqNum);
        return CUnknown("fdAT", frameData);
    }

    private function addIdat(width: Int, height: Int, data: Bytes) {
        var rgb = haxe.io.Bytes.alloc(width * height + height);
		var w = 0;
        var r = 0;
		for( y in 0...height ) {
			rgb.set(w++,0); // no filter for this scanline
			for( x in 0...width )
				rgb.set(w++,data.get(r++));
		}
        chunks.add(CData(format.tools.Deflate.run(rgb, 9)));
    }
}
