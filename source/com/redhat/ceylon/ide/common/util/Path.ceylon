import ceylon.collection {
    ArrayList
}
import ceylon.interop.java {
    javaString
}

import java.io {
    JFile=File
}



 /** Constant root path string (<code>"/"</code>). */
 String _ROOT_STRING = "/"; //$NON-NLS-1$

 """
    Path separator character constant "/" used in paths.
    """
 shared Character _SEPARATOR = '/';

 """
    Device separator character constant ":" used in paths.
    """
 shared Character _DEVICE_SEPARATOR  = ':';

 /** masks for separator values */
 Integer _HAS_LEADING = 1;
 Integer  _IS_UNC = 2;
 Integer _HAS_TRAILING = 4;

 Integer _ALL_SEPARATORS = _HAS_LEADING.or(_IS_UNC).or(_HAS_TRAILING);

 /** Constant empty string value. */
 String _EMPTY_STRING = ""; //$NON-NLS-1$

 /** Constant value indicating no segments */
 Array<String> _NO_SEGMENTS =Array.ofSize(0, "");

 /** Mask for all bits that are involved in the hash code */
 Integer _HASH_MASK = _HAS_TRAILING.not;

 /** Constant value indicating if the current platform is Windows */
 Boolean _WINDOWS = JFile.separatorChar == '\\';



"""
   This class is a Ceylon port of the following Eclipse classes
   ```
   org.eclipse.core.runtime.IPath
   ```
     and
   ```
   org.eclipse.core.runtime.Path
   ```
   that are governed by the following copyright :
   ```
   /*******************************************************************************
   * Copyright (c) 2000, 2008 IBM Corporation and others.
   * All rights reserved. This program and the accompanying materials
   * are made available under the terms of the Eclipse Public License v1.0
   * which accompanies this distribution, and is available at
   * http://www.eclipse.org/legal/epl-v10.html
   *
   * Contributors:
   *     IBM Corporation - initial API and implementation
   *******************************************************************************/
   ```

   A path is an ordered collection of string segments,
   separated by a standard separator character, <code>/</code>.

   A path may also have a leading and/or a trailing separator.

   Paths may also be prefixed by an optional device id, which includes
   the character(s) which separate the device id from the rest
   of the path. For example, <code>C:</code> and <code>Server/Volume:</code>
   are typical device ids.

   A device independent path has [[null]] for a device id.

   Note that paths are value objects; all operations on paths
   return a new path; the path that is operated on is unscathed.

   UNC paths are denoted by leading double-slashes such
   as <code>//Server/Volume/My/Path</code>. When a new path
   is constructed all double-slashes are removed except those
   appearing at the beginning of the path.
   """
shared final class Path satisfies List<String> {
    /** The device id string. May be null if there is no device. */
    variable String? _device=null;

    //Private implementation note: the segments and separators
    //arrays are never modified, so that they can be shared between
    //path instances

    /** The path segments */
    variable Array<String> _segments = _NO_SEGMENTS;


    /** flags indicating separators (has leading, is UNC, has trailing) */
    variable Integer separators=0;

    """
       Returns whether this path is an absolute path (ignoring
       any device id).

       Absolute paths start with a path separator.
       A root path, like <code>/</code> or <code>C:/</code>,
       is considered absolute.  UNC paths are always absolute.

       Returns [[true]] if this path is an absolute path,
       and [[false]] otherwise
       """
    shared Boolean absolute
    //it's absolute if it has a leading separator
        => separators.and(_HAS_LEADING) != 0;

    Integer computeHashCode() {
        variable Integer theHash = if (exists d=_device) then javaString(d).hash else 17;
        for (segment in _segments) {
            //this function tends to given a fairly even distribution
            theHash = theHash * 37 + javaString(segment).hash;
        }
        return theHash;
    }

    """
       Removes duplicate slashes from the given path, with the exception
       of leading double slash which represents a UNC path.
       """
    String collapseSlashes(String path) {
        value length = path.size;
        // if the path is only 0, 1 or 2 chars long then it could not possibly have illegal
        // duplicate slashes.
        if (length < 3) {
            return path;
        }
        // check for an occurrence of // in the path.  Start at index 1 to ensure we skip leading UNC //
        // If there are no // then there is nothing to collapse so just return.
        if (! "//" in path.rest) {
            return path;
        }

        // We found an occurrence of // in the path so do the slow collapse.
        variable Boolean hasPrevious = false;
        return String {
            characters = path.indexed.filter {
                function selecting(Integer->Character entry) {
                    value index=entry.key;
                    value c=entry.item;
                    if (c == _SEPARATOR) {
                        if (hasPrevious) {
                            // skip double slashes, except for beginning of UNC.
                            // note that a UNC path can't have a device.
                            if (! (_device exists) && index == 1) {
                                return true;
                            }
                        } else {
                            hasPrevious = true;
                            return true;
                        }
                    } else {
                        hasPrevious = false;
                        return true;
                    }
                    return false;
                }
            }.map((e) => e.item);
        };
    }

    """
       Returns the number of segments in the given path
       """
    Integer computeSegmentCount(String path) {
        value len = path.size;
        if (len == 0) {
            return 0;
        }
        if (exists first = path.first,
            path.rest.empty,
            first == _SEPARATOR) {
            return 0;
        }
        variable value count = 1;
        variable value prev = -1;
        while (exists i = path.firstOccurrence(_SEPARATOR, prev + 1)) {
            if (i != prev + 1 && i != len) {
                ++count;
            }
            prev = i;
        }
        assert(exists last=path.last);
        if (last == _SEPARATOR) {
            --count;
        }
        return count;
    }

    """
       Computes the segment array for the given canonicalized path.
       """
    Array<String> computeSegments(String path) {
        // performance sensitive --- avoid creating garbage
        Integer segmentCount = computeSegmentCount(path);
        if (segmentCount == 0) {
            return _NO_SEGMENTS;
        }

        assert(exists firstChar = path.first);
        Integer len = path.size;
        // check for initial slash
        variable value firstPosition = if (firstChar == _SEPARATOR) then 1 else 0;
        // check for UNC
        if (firstPosition == 1,
            exists next=path.get(1),
            next == _SEPARATOR) {
            firstPosition = 2;
        }
        value lastPosition = if (exists last=path.last, last != _SEPARATOR) then len - 1 else len - 2;
        // for non-empty paths, the number of segments is
        // the number of slashes plus 1, ignoring any leading
        // and trailing slashes
        variable value next = firstPosition;

        function buildPart(Integer i) {
            value start = next;
            value end = path.firstOccurrence(_SEPARATOR, next);
            if (! exists end) {
                return path.span(start, lastPosition);
            } else {
                next=end+1;
                return path.span(start, end-1);
            }
        }

        return Array((0:segmentCount).map(buildPart));
    }

    """
       Destructively removes all occurrences of ".." segments from this path.
       """
    void collapseParentReferences() {
        value segmentCount = _segments.size;
        value stack = ArrayList<String>(segmentCount);
        for (segment in _segments) {
            if (segment == "..") {
                if (stack.empty) {
                    // if the stack is empty we are going out of our scope
                    // so we need to accumulate segments.  But only if the original
                    // path is relative.  If it is absolute then we can't go any higher than
                    // root so simply toss the .. references.
                    if (!absolute) {
                        stack.push(segment); //stack push
                    }
                } else {
                    // if the top is '..' then we are accumulating segments so don't pop
                    if (exists top=stack.top,
                        top == "..") {
                        stack.push("..");
                    }
                    else {
                        stack.pop();
                        //stack pop
                    }
                }
                //collapse current references
            } else if (segment != "." || segmentCount == 1) {
                stack.push(segment); //stack push
            }
        }
        //if the number of segments hasn't changed, then no modification needed
        if (stack.size == segmentCount) {
            return;
        }
        //build the new segment array backwards by popping the stack
        _segments = Array(stack);
    }


    """
       Destructively converts this path to its canonical form.

       In its canonical form, a path does not have any
       "." segments, and parent references ("..") are collapsed
       where possible.

       Returns [[true]] if the path was modified, and [[false]] otherwise.
       """
    Boolean canonicalize() {
        //look for segments that need canonicalizing
        value max = _segments.size;
        for (i in 0:max) {
            assert(exists segment = _segments[i]);
            if (exists first = segment.first,
                first == '.',
                (segment == ".." || segment == ".")) {
                //path needs to be canonicalized
                collapseParentReferences();
                //paths of length 0 have no trailing separator
                if (_segments.size == 0) {
                    separators = separators.and(_HAS_LEADING.or(_IS_UNC));
                }
                //recompute hash because canonicalize affects hash
                value hashCode = computeHashCode();
                value shiftedHashCode = hashCode.leftLogicalShift(3);
                separators = separators.and(_ALL_SEPARATORS).or(shiftedHashCode);
                return true;
            }
        }
        return false;
    }

    """
       Initialize the current path with the given string.
       """
    void initialize(String? deviceString, variable String path) {
        _device = deviceString;

        path = collapseSlashes(path);
        value len = path.size;

        //compute the separators array
        if (len < 2) {
            if (exists first=path.first,
                path.rest.empty,
                first == _SEPARATOR) {
                separators = _HAS_LEADING;
            } else {
                separators = 0;
            }
        } else {
            assert (exists first=path.first);
            assert (exists second=path.rest.first);
            value hasLeading = first == _SEPARATOR;
            value isUNC = hasLeading && second == _SEPARATOR;
            assert (exists last=path.last);
            //UNC path of length two has no trailing separator
            value hasTrailing = !(isUNC && len == 2) && last == _SEPARATOR;

            separators = if (hasLeading) then _HAS_LEADING else 0;
            if (isUNC) {
                separators = separators.or(_IS_UNC);
            }
            if (hasTrailing) {
                separators = separators.or(_HAS_TRAILING);
            }
        }

        //compute segments and ensure canonical form
        _segments = computeSegments(path);
        if (!canonicalize()) {
            //compute hash now because canonicalize didn't need to do it
            separators = separators.and(_ALL_SEPARATORS).or(computeHashCode().leftLogicalShift(3));
        }
    }

    """
       Constructs a new path from the given string path.
       The string path must represent a valid file system path
       on the local file system.
       The path is canonicalized and double slashes are removed
       except at the beginning. (to handle UNC paths). All forward
       slashes ('/') are treated as segment delimiters, and any
       segment and device delimiters for the local file system are
       also respected (such as colon (':') and backslash ('\') on some file systems).
       """
    shared new(variable String fullPath) {
        variable String? devicePart = null;
        if (_WINDOWS) {
            //convert backslash to forward slash
            fullPath = if (! '\\' in fullPath) then fullPath else fullPath.replace("\\", _SEPARATOR.string);
            //extract device
            value deviceSeparatorIndex = fullPath.firstOccurrence(_DEVICE_SEPARATOR);
            if (exists deviceSeparatorIndex) {
                //remove leading slash from device part to handle output of URL.getFile()
                assert(exists pathFirstChar = fullPath.get(0));
                value start = if (pathFirstChar == _SEPARATOR) then 1 else 0;
                devicePart = fullPath.span(start, deviceSeparatorIndex);
                fullPath = fullPath.spanFrom(deviceSeparatorIndex + 1);
            }
        }
        initialize(devicePart, fullPath);
    }

    """
       Constructs a new path from the given device id and string path.
       The given string path must be valid.
       The path is canonicalized and double slashes are removed except
       at the beginning (to handle UNC paths). All forward
       slashes ('/') are treated as segment delimiters, and any
       segment delimiters for the local file system are
       also respected (such as backslash ('\') on some file systems).
       """
    shared new fromDevice(String device, variable String path) {
        if (_WINDOWS) {
            //convert backslash to forward slash
            path = if (! '\\' in path) then path else path.replace("\\", _SEPARATOR.string);
        }
        initialize(device, path);
    }

    new internalConstructor(String? device, Array<String> segments, Integer _separators) {
        // no segment validations are done for performance reasons
        _segments = segments;
        _device = device;
        //hash code is cached in all but the bottom three bits of the separators field
        this.separators = computeHashCode().leftLogicalShift(3).or(_separators.and(_ALL_SEPARATORS));
    }

    /** Constant value containing the root path with no device. */
    shared new _ROOT extends Path(_ROOT_STRING) { }

    /** Constant value containing the empty path with no device. */
    shared new _EMPTY extends Path(_EMPTY_STRING) { }

    """
       Returns whether this path has no segments and is not
       a root path.

       Returns [[true]] if this path is empty,
          and [[false]] otherwise
       """
    shared Boolean emptyPath {
        //true if no segments and no leading prefix
        return _segments.empty && (separators.and(_ALL_SEPARATORS) != _HAS_LEADING);
    }

    """
       Returns a new path which is the same as this path but with
       the given file extension added.  If this path is empty, root or has a
       trailing separator, this path is returned.  If this path already
       has an extension, the existing extension is left and the given
       extension simply appended.  Clients wishing to replace
       the current extension should first remove the extension and
       then add the desired one.

       The file extension portion is defined as the string
       following the last period (".") character in the last segment.
       The given extension should not include a leading ".".
       """
    shared Path addFileExtension(
        "the file extension to append"
        String extension) {
        if (root || emptyPath || hasTrailingSeparator) {
            return this;
        }
        value len = _segments.size;
        assert(exists last=_segments.last);
        value newSegments = Array.ofSize(len, "");
        _segments.copyTo(newSegments, 0, 0, len-1);
        newSegments.set(len-1, "``last``.``extension``");
        return internalConstructor(device, newSegments, separators);
    }

    """
       Returns a path with the same segments as this path
       but with a trailing separator added.
       This path must have at least one segment.

       If this path already has a trailing separator,
       this path is returned.
       """
    shared Path addTrailingSeparator() {
        if (hasTrailingSeparator || root) {
            return this;
        }
        //XXX workaround, see 1GIGQ9V
        if (emptyPath) {
            return internalConstructor(_device, _segments, _HAS_LEADING);
        }
        return internalConstructor(_device, _segments, separators.or(_HAS_TRAILING));
    }

    """
       Returns the canonicalized path obtained from the
       concatenation of the given string path to the
       end of this path. The given string path must be a valid
       path. If it has a trailing separator,
       the result will have a trailing separator.
       The device id of this path is preserved (the one
       of the given string is ignored). Duplicate slashes
       are removed from the path except at the beginning
       where the path is considered to be UNC.
       """
    shared Path append(
        "the string path to concatenate"
        String tail) {
        //optimize addition of a single segment
        if (!_SEPARATOR in tail && !"\\" in tail && !_DEVICE_SEPARATOR in tail) {
            value tailLength = tail.size;
            if (tailLength < 3) {
                //some special cases
                if (tailLength == 0 || "." == tail) {
                    return this;
                }
                if (".." == tail) {
                    return removeLastSegments(1);
                }
            }
            //just add the segment
            value myLen = _segments.size;
            value newSegments = Array.ofSize(myLen+1, "");
            _segments.copyTo(newSegments, 0, 0, myLen);
            newSegments[myLen] = tail;
            return internalConstructor(_device, newSegments, separators.and(_HAS_TRAILING.not));
        }
        //go with easy implementation
        return appendPath(Path(tail));
    }

    """
       Returns the canonicalized path obtained from the
       concatenation of the given path's segments to the
       end of this path.  If the given path has a trailing
       separator, the result will have a trailing separator.
       The device id of this path is preserved (the one
       of the given path is ignored). Duplicate slashes
       are removed from the path except at the beginning
       where the path is considered to be UNC.
       """
    shared Path appendPath(
        "the path to concatenate"
        Path? tail) {
        //optimize some easy cases
        if (!exists tail) {
            return this;
        }
        if (tail.segmentCount == 0) {
            return this;
        }
        //these call chains look expensive, but in most cases they are no-ops
        if (emptyPath) {
            return tail.withDevice(device).makeRelative().makeUNC(isUNC);
        }
        if (root) {
            return tail.withDevice(device).makeAbsolute().makeUNC(isUNC);
        }

        //concatenate the two segment arrays

        value myLen = segments.size;
        value tailLen = tail.segmentCount;
        value newSegments = Array.ofSize(myLen + tailLen, "");
        _segments.copyTo(newSegments, 0, 0, myLen);
        for (i in 0:tailLen) {
            assert (exists seg = tail.segment(i));
            newSegments[myLen + i] = seg;
        }

        //use my leading separators and the tail's trailing separator
        Path result = internalConstructor(device, newSegments, separators.and(_HAS_LEADING.or(_IS_UNC)).or(if (tail.hasTrailingSeparator) then _HAS_TRAILING else 0));
        assert(exists tailFirstSegment = newSegments[myLen]);
        if (tailFirstSegment == ".." || tailFirstSegment == ".") {
            result.canonicalize();
        }
        return result;
    }

    """
       Returns whether this path equals the given object.

       Equality for paths is defined to be: same sequence of segments,
       same absolute/relative status, and same device.
       Trailing separators are disregarded.
       Paths are not generally considered equal to objects other than paths.

       Returns [[true]] if the paths are equivalent,
       and [[false]] if they are not
       """
    shared actual Boolean equals(Object obj) {
        if (is Identifiable obj,
            this === obj) {
            return true;
        }
        if (!is Path obj) {
            return false;
        }
        value target = obj;
        //check leading separators and hash code
        if (separators.and(_HASH_MASK) != target.separators.and(_HASH_MASK)) {
            return false;
        }
        Array<String> targetSegments = target._segments;

        //check segments in reverse order - later segments more likely to differ

        if (_segments.reversed != targetSegments.reversed) {
            return false;
        }

        //check device last (least likely to differ)
        String? targetDevice = target._device;
        String? currentDevice = _device;

        return if (exists currentDevice, exists targetDevice)
                    then currentDevice == targetDevice
                    else currentDevice is Null && targetDevice is Null;
    }

    shared actual Integer hash => separators.and(_HASH_MASK);

    """
       Device id for this path, or [[null]] if this
       path has no device id. Note that the result will end in `:`.
       """
    shared String? device => _device;

    """
       Returns a new path which is the same as this path but with
       the given device id.  The device id must end with a ":".
       A device independent path is obtained by passing [[null]].

       For example, "C:" and "Server/Volume:" are typical device ids.
       """
    shared Path withDevice(
        "the device id or [[null]]"
        String? newDevice) {
        if (exists newDevice) {
            "Last character should be the device separator"
            assert(
                equalsWithNulls(
                    newDevice.firstOccurrence(_DEVICE_SEPARATOR),
                    newDevice.last));
        }
        //return the receiver if the device is the same
        if (equalsWithNulls(newDevice, _device)) {
            return this;
        }

        return internalConstructor(newDevice, _segments, separators);
    }

    """
       File extension portion of this path,
       or [[null]] if there is none.

       The file extension portion is defined as the string
       following the last period (".") character in the last segment.
       If there is no period in the last segment, the path has no
       file extension portion. If the last segment ends in a period,
       the file extension portion is the empty string.
       """
    shared String? fileExtension {
        if (hasTrailingSeparator) {
            return null;
        }
        value theLastSegment = lastSegment;
        if (theLastSegment is Null) {
            return null;
        }
        assert(exists theLastSegment);
        value index = theLastSegment.lastOccurrence('.');
        return if (exists index) then theLastSegment.spanFrom(index + 1) else null;
    }

    """
       Returns [[true]] if this path has a trailing separator
       and [[false]] otherwise.

       *Note :* In the root path ("/"), the separator is considered to
       be leading rather than trailing.
       """
    shared Boolean hasTrailingSeparator => separators.and(_HAS_TRAILING) != 0;

    """
       Returns whether this path is a prefix of the given path.
       To be a prefix, this path's segments must
       appear in the argument path in the same order,
       and their device ids must match.

       An empty path is a prefix of all paths with the same device; a root path is a prefix of
       all absolute paths with the same device.

       Returns [[true]] if this path is a prefix of the given path,
          and [[false]] otherwise
       """
    shared Boolean isPrefixOf(Path anotherPath) {
        String? currentDevice = _device;
        String? anotherDevice = anotherPath._device;

        if (! equalsWithNulls(currentDevice, anotherDevice, String.equalsIgnoringCase)) {
            return false;
        }

        if (emptyPath || (root && anotherPath.absolute)) {
            return true;
        }

        return anotherPath._segments.startsWith(_segments);
    }

    """
       Returns whether this path is a root path.

       The root path is the absolute non-UNC path with zero segments;
       e.g., <code>/</code> or <code>C:/</code>.
       The separator is considered a leading separator, not a trailing one.


       Returns [[true]] if this path is a root path,
          and [[false]] otherwise
       """
    shared Boolean root
            //must have no segments, a leading separator, and not be a UNC path.
            => this === _ROOT || (_segments.empty && (separators.and(_ALL_SEPARATORS) == _HAS_LEADING));

    """
       Returns a boolean value indicating whether or not this path
       is considered to be in UNC form. Return false if this path
       has a device set or if the first 2 characters of the path string
       are not [[_SEPARATOR]].

       Returns a boolean indicating if this path is UNC
       """
    shared Boolean isUNC {
        if (_device exists) {
            return false;
        }
        return separators.and(_IS_UNC) != 0;
    }

    """
       Returns whether the given string is syntactically correct as
       a path.  The device id is the prefix up to and including the device
       separator for the local file system; the path proper is everything to
       the right of it, or the entire string if there is no device separator.
       When the platform location is a file system with no meaningful device
       separator, the entire string is treated as the path proper.
       The device id is not checked for validity; the path proper is correct
       if each of the segments in its canonicalized form is valid.

       Returns [[true]] if the given string is a valid path,
          and [[false]] otherwise
       """
    shared Boolean isValidPath(String path)
            => Path(path).segments.every((s) => isValidSegment(s));

    """
       Returns whether the given string is valid as a segment in
       a path. The rules for valid segments are as follows:

       - the empty string is not valid
       - any string containing the slash character ('/') is not valid
       - any string containing segment or device separator characters
       on the local file system, such as the backslash ('\') and colon (':')
       on some file systems.

       Returns [[true]] if the given path segment is valid,
          and [[false]] otherwise
       """
    shared Boolean isValidSegment(String segment)
            =>  ! segment.empty &&
                ! segment.any((c)
                    => c == '/' ||
                       (_WINDOWS
                        && (c == '\\' ||
                            c == ':')));

    """
       Returns the last segment of this path, or
       [[null]] if it does not have any segments.

       Returns the last segment of this path, or [[null]]
       """
    shared String? lastSegment => _segments.last;

    """
       Returns an absolute path with the segments and device id of this path.
       Absolute paths start with a path separator. If this path is absolute,
       it is simply returned.

       Returns the new path
       """
    shared Path makeAbsolute() {
        if (absolute) {
            return this;
        }
        Path result = internalConstructor(_device, _segments, separators.or(_HAS_LEADING));
        //may need canonicalizing if it has leading ".." or "." segments
        if (exists first=result._segments.first) {
            if (first == ".." || first == ".") {
                result.canonicalize();
            }
        }
        return result;
    }

    """
       Returns a relative path with the segments and device id of this path.
       Absolute paths start with a path separator and relative paths do not.
       If this path is relative, it is simply returned.

       Returns the new path
       """
    shared Path makeRelative() {
        if (! absolute) {
            return this;
        }
        return internalConstructor(_device, _segments, separators.and(_HAS_TRAILING));
    }

    """
       Returns a path equivalent to this path, but relative to the given base path if possible.

       The path is only made relative if the base path if both paths have the same device
       and have a non-zero length common prefix. If the paths have different devices,
       or no common prefix, then this path is simply returned. If the path is successfully
       made relative, then appending the returned path to the base will always produce
       a path equal to this path.

       Returns A path relative to the base path, or this path if it could
       not be made relative to the given base
       """
    shared Path makeRelativeTo(
        "The base path to make this path relative to"
        Path base) {
        //can't make relative if devices are not equal
        if (! equalsWithNulls(_device, base._device, String.equalsIgnoringCase)) {
            return this;
        }

        value commonLength = matchingFirstSegments(base);
        value differenceLength = base.segmentCount - commonLength;
        value newSegmentLength = differenceLength + segmentCount - commonLength;
        if (newSegmentLength == 0) {
            return _EMPTY;
        }
        //add parent references for each segment different from the base
        value newSegments = Array.ofSize(newSegmentLength, "..");
        //append the segments of this path not in common with the base
        _segments.copyTo(newSegments, commonLength, differenceLength, newSegmentLength - differenceLength);
        return internalConstructor(null, newSegments, separators.and(_HAS_TRAILING));
    }

    """
       Return a new path which is the equivalent of this path converted to UNC
       form (if the given boolean is true) or this path not as a UNC path (if the given
       boolean is false). If UNC, the returned path will not have a device and the
       first 2 characters of the path string will be [[_SEPARATOR]]. If not UNC, the
       first 2 characters of the returned path string will not be [[_SEPARATOR]].

       Returns the new path, either in UNC form or not depending on the boolean parameter
       """
    shared Path makeUNC(
        "true if converting to UNC, false otherwise"
        Boolean toUNC) {
        // if we are already in the right form then just return
        if (toUNC == isUNC) {
            return this;
        }

        Integer newSeparators;
        if (toUNC) {
            newSeparators = separators.or(_HAS_LEADING.or(_IS_UNC));
        } else {
            //mask out the UNC bit
            newSeparators = separators.and(_HAS_LEADING.or(_HAS_TRAILING));
        }
        return internalConstructor(if (toUNC) then null else device, _segments, newSeparators);
    }

    """
       Returns a count of the number of segments which match in
       this path and the given path (device ids are ignored),
       comparing in increasing segment number order.
       """
    shared Integer matchingFirstSegments(Path anotherPath)
            => zipPairs(_segments, anotherPath._segments)
                .takeWhile((String[2] paths) => paths[0] == paths[1])
                .size;

    """
       Returns a new path which is the same as this path but with
       the file extension removed.  If this path does not have an
       extension, this path is returned.

       The file extension portion is defined as the string
       following the last period (".") character in the last segment.
       If there is no period in the last segment, the path has no
       file extension portion. If the last segment ends in a period,
       the file extension portion is the empty string.
       """
    shared Path removeFileExtension() {
        String? extension = fileExtension;
        if (extension is Null) {
            return this;
        }
        assert(exists extension);
        if (extension.empty) {
            return this;
        }
        assert(exists theLastSegment = lastSegment);
        assert(exists extensionPlace = theLastSegment.lastInclusion(extension));
        return removeLastSegments(1).append(theLastSegment.span(0, extensionPlace-2));
    }

    """
       Returns a copy of this path with the given number of segments
       removed from the beginning. The device id is preserved.
       The number must be greater or equal zero.
       If the count is zero, this path is returned.
       The resulting path will always be a relative path with respect
       to this path.  If the number equals or exceeds the number
       of segments in this path, an empty relative path is returned.
       """
    shared Path removeFirstSegments(
        "the number of segments to remove"
        Integer count) {
        if (count == 0) {
            return this;
        }

        if (count >= _segments.size) {
            return internalConstructor(_device, _NO_SEGMENTS, 0);
        }
        value newSize = _segments.size - count;
        value newSegments = Array.ofSize(newSize, "");
        _segments.copyTo(newSegments,count, 0, newSize);

        //result is always a relative path
        return internalConstructor(_device, newSegments, separators.and(_HAS_TRAILING));
    }

    """
       Returns a copy of this path with the given number of segments
       removed from the end. The device id is preserved.
       The number must be greater or equal zero.
       If the count is zero, this path is returned.

       If this path has a trailing separator, it will still
       have a trailing separator after the last segments are removed
       (assuming there are some segments left).  If there is no
       trailing separator, the result will not have a trailing
       separator.
       If the number equals or exceeds the number
       of segments in this path, a path with no segments is returned.
       """
    shared Path removeLastSegments(
        "the number of segments to remove"
        Integer count) {
        if (count == 0) {
            return this;
        }

        if (count >= _segments.size) {
            //result will have no trailing separator
            return internalConstructor(_device, _NO_SEGMENTS, separators.and(_HAS_LEADING.or(_IS_UNC)));
        }
        value newSize = _segments.size - count;
        Array<String> newSegments = Array.ofSize(newSize, "");
        _segments.copyTo(newSegments, 0, 0, newSize);
        return internalConstructor(_device, newSegments, separators);
    }

    """
       Returns a path with the same segments as this path
       but with a trailing separator removed.
       Does nothing if this path does not have at least one segment.
       The device id is preserved.

       If this path does not have a trailing separator,
       this path is returned.
       """
    shared Path removeTrailingSeparator() {
        if (!hasTrailingSeparator) {
            return this;
        }
        return internalConstructor(device, _segments, separators.and(_HAS_LEADING.or(_IS_UNC)));
    }

    """
       Returns the specified segment of this path, or
       [[null]] if the path does not have such a segment.
       """
    shared String? segment(
        "the 0-based segment index"
        Integer index) => _segments[index];

    """
       Returns the number of segments in this path.

       Note that both root and empty paths have 0 segments.
       """
    shared Integer segmentCount => _segments.size;

    """
       Returns the segments in this path in order.
       """
    shared [String*] segments => _segments.sequence();

    """
       Returns a [[java.io::File]] corresponding to this path.
       """
    shared JFile file => JFile(platformDependentString);

    String stringInternal(Character fileSeparator) {
        value builder = StringBuilder();
        if (exists dev=_device) {
            builder.append(dev);
        }
        if (separators.and(_HAS_LEADING) != 0) {
            builder.appendCharacter(fileSeparator);
        }
        if (separators.and(_IS_UNC) != 0) {
            builder.appendCharacter(fileSeparator);
        }
        //append all but the last segment, with separators
        for (segment in _segments.exceptLast) {
            builder.append(segment);
            builder.appendCharacter(fileSeparator);
        }
        //append the last segment
        if (exists last = _segments.last) {
            builder.append(last);
        }

        if (separators.and(_HAS_TRAILING) != 0) {
            builder.appendCharacter(fileSeparator);
        }
        if (builder.empty) {
            return _EMPTY_STRING;
        }

        return builder.string;
    }

    """
       Returns a string representation of this path which uses the
       platform-dependent path separator defined by [[java.io::File]].
       This method is like [[string]] except that the
       latter always uses the same separator (<code>/</code>) regardless of platform.

       This string is suitable for passing to [[java.io::File(String)]]</code>.
       """
    shared String platformDependentString
            => stringInternal(JFile.separatorChar);

    """
       Returns a string representation of this path, including its
       device id.  The same separator, "/", is used on all platforms.

       Example result strings (without and with device id):
       ```
       "/foo/bar.txt"
       "bar.txt"
       "/foo/"
       "foo/"
       ""
       "/"
       "C:/foo/bar.txt"
       "C:bar.txt"
       "C:/foo/"
       "C:foo/"
       "C:"
       "C:/"
       ```

       This string is suitable for passing to [[Path(String)]]</code>.
       """
    shared actual String string
            => stringInternal(_SEPARATOR);

    """
       Returns a copy of this path truncated after the
       given number of segments. The number must not be negative.
       The device id is preserved.

       If this path has a trailing separator, the result will too
       (assuming there are some segments left). If there is no
       trailing separator, the result will not have a trailing
       separator.
       Copying up to segment zero simply means making an copy with
       no path segments.
       """
    shared Path uptoSegment(
        "the segment number at which to truncate the path"
        Integer count) {
        if (count == 0) {
            return internalConstructor(_device, _NO_SEGMENTS, separators.and(_HAS_LEADING.or(_IS_UNC)));
        }
        if (count >= _segments.size) {
            return this;
        }
        "Invalid parameter to Path.uptoSegment"
        assert(count > 0);
        value newSegments = Array.ofSize(count, "");
        _segments.copyTo(newSegments, 0, 0, count);
        return internalConstructor(device, newSegments, separators);
    }
    shared actual String? getFromFirst(Integer index) => _segments.getFromFirst(index);

    shared actual Integer? lastIndex => _segments.lastIndex;
}
