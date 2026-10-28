import Darwin
import Foundation

/// An empty, per-user lock. Closing the descriptor (including on a crash)
/// releases ownership; never unlink a lock that another launcher may have open.
public final class SingleInstanceLease: Sendable {
    private let descriptor: Int32
    private init(descriptor: Int32) { self.descriptor = descriptor }
    deinit { close(descriptor) }

    /// Returns nil only when another process already owns the lock.
    public static func acquire(at url: URL) throws -> SingleInstanceLease? {
        let descriptor = open(url.path, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        var acquired = false
        defer { if !acquired { close(descriptor) } }
        var attributes = stat()
        guard fstat(descriptor, &attributes) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard attributes.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              attributes.st_uid == getuid(), attributes.st_nlink == 1,
              attributes.st_mode & 0o077 == 0 else { throw POSIXError(.EPERM) }
        if flock(descriptor, LOCK_EX | LOCK_NB) != 0 {
            let code = errno
            if code == EWOULDBLOCK || code == EAGAIN { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        acquired = true
        return SingleInstanceLease(descriptor: descriptor)
    }
}
