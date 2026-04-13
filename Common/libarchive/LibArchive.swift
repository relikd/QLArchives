import Foundation

enum LibArchiveError: Error, LocalizedError {
	case generic(String)
	
	var errorDescription: String? {
		switch self {
		case .generic(let msg): msg
		}
	}
}

class LibArchive: IteratorProtocol, Sequence {
	typealias Element = ArchiveEntry
	
	/// Pointer to `archive`
	private var ptr_archive: OpaquePointer?
	/// Pointer to `archive_entry`
	private var ptr_entry: OpaquePointer?
	/// Incremented during entry iteration
	private var currentIndex: UInt = 0
	/// Number of items in archive
	/// @Note only accurate after all entries have been processed
	var count: UInt { currentIndex }
	/// File system size
	let compressedSize: Int64
	/// Uncompressed size of all items
	/// @Note only accurate after all entries have been processed
	var uncompressedSize: Int64 = 0

	init(_ url: URL) throws {
		let path = url.path// url.path(percentEncoded: false)
		compressedSize = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int64 ?? -1
		
		let archive = archive_read_new()
		archive_read_support_filter_all(archive)
		archive_read_support_format_all(archive)
		let r = archive_read_open_filename(archive, path, 102400)
		if (r != ARCHIVE_OK) {
			if let reason = archive_error_string(archive) {
				throw LibArchiveError.generic(String(cString: reason))
			}
			throw LibArchiveError.generic("could not load archive")
		}
		self.ptr_archive = archive
	}
	
	deinit {
		close()
	}
	
	/// Returns version of libarchive framework `"libarchive X.Y.Z"`
	static func version() -> String {
		String(cString: archive_version_string())
	}
	
	/// No need to call manually, will close archive automatically after last entry
	func close() {
		if ptr_archive != nil {
			ptr_entry = nil
			archive_read_free(ptr_archive)
			ptr_archive = nil
		}
	}
	
	/// Read next `archive_entry`. Returns `nil` if `EOF`.
	func next() -> ArchiveEntry? {
		guard ptr_archive != nil else {
			return nil
		}
		var entry: OpaquePointer?
		guard archive_read_next_header(ptr_archive, &entry) == ARCHIVE_OK else {
			self.close()
			return nil
		}
		ptr_entry = entry
		currentIndex += 1
		let typ = Filetype(rawValue: archive_entry_filetype(ptr_entry)) ?? .Undefined
		let size = Int64(archive_entry_size(ptr_entry))
		uncompressedSize += size
		return ArchiveEntry(
			index: currentIndex - 1,
			path: String(cString: archive_entry_pathname(ptr_entry)),
			size: typ == .Directory ? -1 : size,
			perm: Perm(raw: archive_entry_perm(ptr_entry)),
			filetype: typ,
			modified: archive_entry_mtime(ptr_entry),
		)
	}
	
	/// Skips X entries. Used for `extract()` operation.
	func skip(_ count: UInt) -> Bool {
		guard ptr_archive != nil else {
			return false
		}
		var entry: OpaquePointer?
		for _ in 0..<count {
			if archive_read_next_header(ptr_archive, &entry) != ARCHIVE_OK {
				self.close()
				return false
			}
		}
		if count > 0 {
			currentIndex += count
		}
		return true
	}
	
	/// Extract data of a single entry with given `index` into file at `url`.
	/// Returns `true` if extraction was successful.
	@discardableResult
	func extract(_ index: UInt, to url: URL) throws -> Bool {
		guard skip(index) else {
			return false
		}
		guard let entry = next() else {
			self.close()
			return false
		}
		
		// special case symlink
		if entry.filetype == .SymbolicLink {
			guard let link = archive_entry_symlink(ptr_entry) else {
				return false
			}
			// FIXME: how to set modification date on symlink?
			try FileManager.default.createSymbolicLink(atPath: url.path, withDestinationPath: String(cString: link))
			return true
		}
		
		// write file content
		FileManager.default.createFile(atPath: url.path, contents: nil)
		let fh = try FileHandle(forWritingTo: url)
		let success = archive_read_data_into_fd(ptr_archive, fh.fileDescriptor)
		try fh.close()
		
		// restore file flags
		var attrs: [FileAttributeKey : Any] = [:]
		
		if entry.perm.raw > 0 {
			attrs[.posixPermissions] = entry.perm.raw
		}
		if archive_entry_mtime_is_set(ptr_entry) > 0 {
			attrs[.modificationDate] = Date(timeIntervalSince1970: TimeInterval(entry.modified))
		}
		if archive_entry_ctime_is_set(ptr_entry) > 0 {
			attrs[.creationDate] = Date(timeIntervalSince1970: TimeInterval(archive_entry_ctime(ptr_entry)))
		}
		if !attrs.isEmpty {
			try? FileManager.default.setAttributes(attrs, ofItemAtPath: url.path)
		}
		return success == ARCHIVE_OK
	}
	
	/// Read all symlinks and store into Hashmap where key is archive index.
	func symlinks() -> [UInt: String] {
		var rv: [UInt: String] = [:]
		var entry: OpaquePointer?
		var i: UInt = 0
		while archive_read_next_header(ptr_archive, &entry) == ARCHIVE_OK {
			if archive_entry_filetype(entry) == Filetype.SymbolicLink.rawValue {
				rv[i] = String(cString: archive_entry_symlink(entry))
			}
			i += 1
		}
		self.close()
		return rv
	}
}

struct ArchiveEntry {
	/// Index of entry inside archvie file
	let index: UInt
	/// Path name
	let path: String
	/// Data length of uncompressed data
	let size: Int64
	/// POSIX file permissions
	let perm: Perm
	/// Type of entry (file, directory, symlink, etc.)
	let filetype: Filetype
	/// Last modified timestamp
	let modified: time_t
}

struct Perm: CustomDebugStringConvertible {
	let raw: mode_t
	
	var setuid: Bool { raw & 0o4000 != 0 }
	var setgid: Bool { raw & 0o2000 != 0 }
	var sticky: Bool { raw & 0o1000 != 0 }
	var owner: UInt8 { UInt8(raw >> 6 & 7) }
	var group: UInt8 { UInt8(raw >> 3 & 7) }
	var other: UInt8 { UInt8(raw & 7) }
	
	var str: String { String(raw, radix: 8) }
	var debugDescription: String { str }
}

// for whatever reason we cannot use `AE_IFDIR` etc.
enum Filetype: mode_t {
	case Undefined       = 0o0000000
	case RegularFile     = 0o0100000
	case SymbolicLink    = 0o0120000
	case Socket          = 0o0140000
	case CharacterDevice = 0o0020000
	case BlockDevice     = 0o0060000
	case Directory       = 0o0040000
	case NamedPipe       = 0o0010000
	
	static let dirs: [Self] = [.Directory]
	static let links: [Self] = [.SymbolicLink]
	static let files: [Self] = [.RegularFile, .Socket, .CharacterDevice, .BlockDevice, .NamedPipe]
}
