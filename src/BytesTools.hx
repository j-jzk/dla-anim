import haxe.io.Bytes;

class BytesTools {
    public static function setInt32BE(self: Bytes, pos: Int, val: Int) {
        self.set(pos+3, val & 0xff);
        val >>= 8;
        self.set(pos+2, val & 0xff);
        val >>= 8;
        self.set(pos+1, val & 0xff);
        val >>= 8;
        self.set(pos+0, val & 0xff);
    }
}
