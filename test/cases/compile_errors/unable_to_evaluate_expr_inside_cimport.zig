const c = @cImport({
    _ = 1 + foo;
});
extern var foo: i32;
export fn entry() void {
    _ = c;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: unable to evaluate comptime expression
// :2:13: note: operation is runtime due to this operand
// :1:11: note: operand to '@cImport' is evaluated at comptime
