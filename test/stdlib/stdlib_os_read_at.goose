// stdlib/os.goose's file_size and read_file_at, in a scratch directory the
// test makes and removes: a 300000-byte file whose bytes all differ from
// their neighbours' read back at its start, in its middle and up to its
// last byte, each byte where it should be; the sizes of an empty file, a
// directory and a missing file; and the reads that fail: past the end,
// before the start, of a directory and of a missing file.
import os;

// Byte i of the file.
fn b(i: i64) -> u8 { ((i * 7 + (i >> 8) * 3) & 255) as u8 }

// How many bytes of out are not the file's from offset on.
fn wrong(out: u8[:], offset: i64) -> i64 {
    var n = 0;
    for i in out.len { if out[i] != b(offset + i) { n++; } }
    n
}

fn main() {
    let dir = "gs_os_read_at_tmp";
    let path = str(dir, "/data.bin");
    let empty = str(dir, "/empty.bin");
    delete_file(path);
    delete_file(empty);
    delete_dir(dir);
    print(make_dir(dir));                                           // true
    var data: u8[>..] = [];
    for i in 300000 { data.push(b(i)); }
    print(write_file(path, data), " ", write_file(empty, ""));     // true true
    print("sizes: ", file_size(path), " ", file_size(empty), " ", file_size(dir), " ",
          file_size(str(dir, "/missing.bin")));                     // 300000 0 -1 -1

    var head: u8[4] = [0, 0, 0, 0];
    print("start: ", read_file_at(path, 0, head), " ", head[0], ",", head[1], ",", head[2], ",", head[3]);
    var mid: u8[1000] = [0; 1000];
    print("middle: ", read_file_at(path, 123457, mid), ", bytes wrong ", wrong(mid, 123457),
          ", first ", mid[0]);
    var tail: u8[10] = [0; 10];
    print("up to the last byte: ", read_file_at(path, 299990, tail), ", bytes wrong ",
          wrong(tail, 299990));
    print("past the end: ", read_file_at(path, 299995, tail), " ", read_file_at(path, 400000, head));
    print("before the start: ", read_file_at(path, -1, head));
    print("a directory: ", read_file_at(dir, 0, head), ", a missing file: ",
          read_file_at(str(dir, "/missing.bin"), 0, head));

    print(delete_file(path), " ", delete_file(empty), " ", delete_dir(dir));   // true true true
}
