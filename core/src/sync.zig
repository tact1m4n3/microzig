const microzig = @import("microzig.zig");

/// Return the mutex type to use.  If a target provides its own mutex type
/// in its HAL, use that; otherwise, use the default `InterruptSafeMutex`.
///
/// Create a mutex instance with `var mutex = Mutex.init(.{});`.
///
/// Lock it (blocking) with `mutex.lock();`,
/// try to lock it (non-blocking) with `const success: bool = mutex.try_lock();`,
/// and unlock it with `mutex.unlock();`.
///
pub const Mutex = if (microzig.config.has_hal and @hasDecl(microzig.hal, "mutex") and @hasDecl(microzig.hal.mutex, "Mutex"))
    microzig.hal.mutex.Mutex
else
    InterruptSafeMutex;

/// This is an implementation of a mutex that simply wraps the interrupt
/// critical section functionality.
///
pub const InterruptSafeMutex = struct {
    critical_section: ?microzig.interrupt.CriticalSection = null,

    /// Try to lock the mutex.
    /// If the mutex was already locked return false.
    pub fn try_lock(self: *InterruptSafeMutex) bool {
        const cs = microzig.interrupt.enter_critical_section();
        if (self.critical_section != null) {
            cs.leave();
            return false;
        }
        self.critical_section = cs;
        return true;
    }

    /// Makes sure the mutex is locked.
    /// If this function is called from within a block of code that already
    /// held the mutex it will panic.
    pub fn lock(self: *InterruptSafeMutex) void {
        if (!self.try_lock()) @panic("mutex already locked");
    }

    /// Unlocks the mutex.
    pub fn unlock(self: *InterruptSafeMutex) void {
        if (self.critical_section) |cs| {
            cs.leave();
            self.critical_section = null;
        }
    }
};
