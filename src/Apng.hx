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

enum ColorType {
    Grey;
    RGB;
}

/**
 * Basic APNG tools, tailored to the needs of this project
 */
class Apng {
    public var chunks: List<Chunk> = new List();

    public function new() {}
    // public function new() {
    //     chunks = new List();
    // }

    public function init(width: Int, height: Int, numFrames: Int, colorScheme: Color, ?palette: Bytes) {
        chunks.add(CHeader({
            width: width,
            height: height,
            interlaced: false,
            colbits: 8,
            color: colorScheme,
        }));
        chunks.add(generateActl(numFrames, 1));

        if (palette != null)
            chunks.add(CPalette(palette));

        // add a black frame
        var black = Bytes.alloc(width * height);
        black.fill(0, black.length, 0);
        addIdat(width, height, black);
        addFrame(0, 0, width, height, 1, black, 9);
    }

    private var seqNum = 0;
    public function addFrame(x: Int, y: Int, width: Int, height: Int, durationMs: Int, data: Bytes, compLvl: Int = 0) {
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

        // final fdat = switch color {
        //     case Grey: generateGreyData(width, height, data);
        //     case RGB: generateRGBData(width, height, data);
        // };
        // fdat.setInt32BE(0, seqNum++);
        chunks.add(generateFdat(seqNum++, generate1ByteData(width, height, data), compLvl));
    }

    /*
    * Adapted from format - Haxe File Formats
    *
    * Copyright (c) 2008-2009, The Haxe Project Contributors
    * All rights reserved.
    * Redistribution and use in source and binary forms, with or without
    * modification, are permitted provided that the following conditions are met:
    *
    *   - Redistributions of source code must retain the above copyright
    *     notice, this list of conditions and the following disclaimer.
    *   - Redistributions in binary form must reproduce the above copyright
    *     notice, this list of conditions and the following disclaimer in the
    *     documentation and/or other materials provided with the distribution.
    *
    * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
    * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
    * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
    * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
    * DAMAGE.
    */
    private function generate1ByteData(width: Int, height: Int, data: Bytes): Bytes {
        // stolen from format.png.tools.buildGrey()
        var fdat = haxe.io.Bytes.alloc(width * height + height);
        var w = 0, r = 0;
		for( y in 0...height ) {
			fdat.set(w++,0); // no filter for this scanline
			for( x in 0...width )
				fdat.set(w++,data.get(r++));
		}
        return fdat;
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
