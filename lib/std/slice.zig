const std = @import("std.zig");

pub fn slice(comptime T: type) type {
    return struct {
        /// Copy all of source into dest at position 0.
        /// dest.len must be >= source.len.
        /// If the slices overlap, dest.ptr must be <= src.ptr.
        pub fn copyForwards(dest: []T, source: []const T) void {
            for (dest[0..source.len], source) |*d, s| d.* = s;
        }

        /// Copy all of source into dest at position 0.
        /// dest.len must be >= source.len.
        /// If the slices overlap, dest.ptr must be >= src.ptr.
        pub fn copyBackwards(dest: []T, source: []const T) void {
            // TODO instead of manually doing this check for the whole array
            // and turning off runtime safety, the compiler should detect loops like
            // this and automatically omit safety checks for loops
            @setRuntimeSafety(false);
            std.debug.assert(dest.len >= source.len);
            var i = source.len;
            while (i > 0) {
                i -= 1;
                dest[i] = source[i];
            }
        }

        /// Compares two slices of numbers lexicographically. O(n).
        pub fn order(lhs: []const T, rhs: []const T) std.math.Order {
            const n = @min(lhs.len, rhs.len);
            for (lhs[0..n], rhs[0..n]) |lhs_elem, rhs_elem| {
                switch (std.math.order(lhs_elem, rhs_elem)) {
                    .eq => continue,
                    .lt => return .lt,
                    .gt => return .gt,
                }
            }
            return std.math.order(lhs.len, rhs.len);
        }

        test order {
            const bytes = std.slice(u8);

            try std.testing.expect(bytes.order("abcd", "bee") == .lt);
            try std.testing.expect(bytes.order("abc", "abc") == .eq);
            try std.testing.expect(bytes.order("abc", "abc0") == .lt);
            try std.testing.expect(bytes.order("", "") == .eq);
            try std.testing.expect(bytes.order("", "a") == .lt);
        }

        /// Returns true if lhs < rhs, false otherwise
        pub fn lessThan(lhs: []const T, rhs: []const T) bool {
            return order(lhs, rhs) == .lt;
        }

        test lessThan {
            const bytes = std.slice(u8);

            try std.testing.expect(bytes.lessThan("abcd", "bee"));
            try std.testing.expect(!bytes.lessThan("abc", "abc"));
            try std.testing.expect(bytes.lessThan("abc", "abc0"));
            try std.testing.expect(!bytes.lessThan("", ""));
            try std.testing.expect(bytes.lessThan("", "a"));
        }

        /// Compares two slices and returns the index of the first inequality.
        /// Returns null if the slices are equal.
        pub fn indexOfDiff(a: []const T, b: []const T) ?usize {
            const shortest = @min(a.len, b.len);
            if (a.ptr == b.ptr)
                return if (a.len == b.len) null else shortest;
            var index: usize = 0;
            while (index < shortest) : (index += 1) if (a[index] != b[index]) return index;
            return if (a.len == b.len) null else shortest;
        }

        test indexOfDiff {
            const bytes = std.slice(u8);

            try std.testing.expectEqual(bytes.indexOfDiff("one", "one"), null);
            try std.testing.expectEqual(bytes.indexOfDiff("one two", "one"), 3);
            try std.testing.expectEqual(bytes.indexOfDiff("one", "one two"), 3);
            try std.testing.expectEqual(bytes.indexOfDiff("one twx", "one two"), 6);
            try std.testing.expectEqual(bytes.indexOfDiff("xne", "one"), 0);
        }

        /// Returns true if all elements in a slice are equal to the scalar value provided
        pub fn allEqual(elements: []const T, scalar: T) bool {
            for (elements) |item| {
                if (item != scalar) return false;
            }
            return true;
        }

        /// Remove a set of values from the beginning of a slice.
        pub fn trimLeft(elements: []const T, values_to_strip: []const T) []const T {
            var begin: usize = 0;
            while (begin < elements.len and indexOfScalar(T, values_to_strip, elements[begin]) != null) : (begin += 1) {}
            return elements[begin..];
        }
    };
}
