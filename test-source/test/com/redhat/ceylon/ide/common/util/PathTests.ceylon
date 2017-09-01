/*******************************************************************************
 *  Copyright (c) 2000, 2008 IBM Corporation and others.
 *  All rights reserved. This program and the accompanying materials
 *  are made available under the terms of the Eclipse Public License v1.0
 *  which accompanies this distribution, and is available at
 *  http://www.eclipse.org/legal/epl-v10.html
 *
 *  Contributors:
 *     IBM Corporation - initial API and implementation
 *******************************************************************************/



import java.net{
    MalformedURLException
}

import com.redhat.ceylon.ide.common.util {
    Path
}
import java.io {
    JFile=File
}
import ceylon.collection {
    ArrayList
}

import ceylon.test {
    ceylonAssertEquals=assertEquals,
    ceylonAssertTrue=assertTrue,
    ceylonFail=fail,
    ceylonAssertNull=assertNull,
    test
}

"""
   This class is a Ceylon port of the following Eclipse class
   ```
   org.eclipse.core.tests.runtime.PathTest
   ```
   that is governed by the following copyright :
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
   """
shared class PathTests() {
    void assertSame(String description, Identifiable expected, Identifiable actual)
            => ceylonAssertEquals {
        actual = actual;
        expected = expected;
        message = description;
        function compare(Anything val1, Anything val2) {
            assert(is Identifiable val1,
                is Identifiable val2);
            return val1 === val2;
        }
    };

    void assertEquals(String description, Anything expected, Anything actual)
            => ceylonAssertEquals(actual, expected, description);

    void assertTrue(String description, Boolean boolean)
            => ceylonAssertTrue(boolean, description);

    void fail(String description, Exception e)
            => ceylonFail(description + e.message);

    void assertNull(String description, String? arg)
            => ceylonAssertNull(arg, description);



    Boolean \iWINDOWS = JFile.separatorChar == '\\';

    test shared void testAddTrailingSeparator(){
        variable Path with = Path("/first/second/third/");
        variable Path without = Path("/first/second/third");
        assertSame("1.0", with, with.addTrailingSeparator());
        assertEquals("1.1", with, without.addTrailingSeparator());
        assertTrue("1.2", without.equals(without.addTrailingSeparator()));
        assertSame("2.0", Path._ROOT, Path._ROOT.addTrailingSeparator());
        assertEquals("2.1", Path._ROOT, Path._EMPTY.addTrailingSeparator());
        with=Path("//first/second/third/");
        without=Path("//first/second/third");
        assertSame("3.0", with, with.addTrailingSeparator());
        assertEquals("3.1", with, without.addTrailingSeparator());
        assertTrue("3.2", without.equals(without.addTrailingSeparator()));
        assertSame("4.0", Path._ROOT, Path._ROOT.addTrailingSeparator());
        assertEquals("4.1", Path._ROOT, Path._EMPTY.addTrailingSeparator());
        with=Path("c:/first/second/third/");
        without=Path("c:/first/second/third");
        assertSame("5.0", with, with.addTrailingSeparator());
        assertEquals("5.1", with, without.addTrailingSeparator());
        assertTrue("5.2", without.equals(without.addTrailingSeparator()));
        assertSame("6.0", Path._ROOT, Path._ROOT.addTrailingSeparator());
        assertEquals("6.1", Path._ROOT, Path._EMPTY.addTrailingSeparator());
    }
    test shared void testAppend(){
        variable Path fore = Path("/first/second/third/");
        variable String aftString = "/fourth/fifth";
        variable Path aft = Path(aftString);
        variable Path combo = Path("/first/second/third/fourth/fifth");
        assertEquals("1.0", combo, fore.appendPath(aft));
        assertEquals("1.1", combo, fore.removeTrailingSeparator().appendPath(aft));
        assertEquals("1.2", combo, Path._ROOT.appendPath(fore).appendPath(aft));
        assertTrue("1.3", !fore.appendPath(aft).hasTrailingSeparator);
        assertTrue("1.4", !Path._ROOT.appendPath(fore).appendPath(aft).hasTrailingSeparator);
        assertTrue("1.5", !fore.removeTrailingSeparator().appendPath(aft).hasTrailingSeparator);
        assertEquals("2.0", combo, fore.append(aftString));
        assertEquals("2.1", combo, fore.removeTrailingSeparator().append(aftString));
        assertEquals("2.2", combo, Path._ROOT.appendPath(fore).append(aftString));
        assertTrue("2.3", !fore.append(aftString).hasTrailingSeparator);
        assertTrue("2.4", !Path._ROOT.appendPath(fore).append(aftString).hasTrailingSeparator);
        assertTrue("2.5", !fore.removeTrailingSeparator().append(aftString).hasTrailingSeparator);
        assertTrue("3.0", !fore.append("aft").hasTrailingSeparator);
        assertTrue("3.1", fore.append("aft/").hasTrailingSeparator);
        assertTrue("3.2", !fore.append("/aft").hasTrailingSeparator);
        assertTrue("3.3", fore.append("/aft/").hasTrailingSeparator);
        assertTrue("3.4", !fore.append("\\aft").hasTrailingSeparator);
        assertTrue("3.5", fore.append("aft\\").hasTrailingSeparator == \iWINDOWS);
        assertTrue("3.6", !fore.append("fourth/fifth").hasTrailingSeparator);
        assertTrue("3.7", fore.append("fourth/fifth/").hasTrailingSeparator);
        assertTrue("3.8", !fore.appendPath(Path("aft")).hasTrailingSeparator);
        assertTrue("3.9", fore.appendPath(Path("aft/")).hasTrailingSeparator);
        assertTrue("3.10", !fore.appendPath(Path("fourth/fifth")).hasTrailingSeparator);
        assertTrue("3.11", fore.appendPath(Path("fourth/fifth/")).hasTrailingSeparator);
        if(\iWINDOWS){
            aftString="fourth\\fifth";
            assertEquals("4.0", combo, fore.append(aftString));
            assertEquals("4.1", combo, fore.removeTrailingSeparator().append(aftString));
            assertEquals("4.2", combo, Path._ROOT.appendPath(fore).append(aftString));
        }
        assertEquals("5.0", Path("/foo"), Path._ROOT.append("../foo"));
        assertEquals("5.1", Path("/foo"), Path._ROOT.append("./foo"));
        assertEquals("5.2", Path("c:/foo/xyz"), Path("c:/foo/bar").append("../xyz"));
        assertEquals("5.3", Path("c:/foo/bar/xyz"), Path("c:/foo/bar").append("./xyz"));
        if(\iWINDOWS){
            assertEquals("6.1", Path("c:foo/bar"), Path("c:").append("/foo/bar"));
            assertEquals("6.2", Path("c:foo/bar"), Path("c:").append("foo/bar"));
            assertEquals("6.3", Path("c:/foo/bar"), Path("c:/").append("/foo/bar"));
            assertEquals("6.4", Path("c:/foo/bar"), Path("c:/").append("foo/bar"));
            assertEquals("6.5", Path("c:foo/bar"), Path("c:").append("z:/foo/bar"));
            assertEquals("6.6", Path("c:foo/bar"), Path("c:").append("z:foo/bar"));
            assertEquals("6.7", Path("c:/foo/bar"), Path("c:/").append("z:/foo/bar"));
            assertEquals("6.8", Path("c:/foo/bar"), Path("c:/").append("z:foo/bar"));
            assertEquals("6.9", Path("c:/foo"), Path("c:/").append("z:foo"));
        }
        else {
            assertEquals("6.1", Path("c:/foo/bar"), Path("c:").append("/foo/bar"));
            assertEquals("6.2", Path("c:/foo/bar/"), Path("c:").append("foo/bar/"));
            assertEquals("6.3", Path("/c:/foo/bar"), Path("/c:").append("/foo/bar"));
            assertEquals("6.4", Path("/c:/foo/bar"), Path("/c:").append("foo/bar"));
        }
        assertEquals("6.10", Path("foo/bar"), Path("foo").appendPath(Path("/bar")));
        assertEquals("6.11", Path("foo/bar"), Path("foo").appendPath(Path("bar")));
        assertEquals("6.12", Path("/foo/bar"), Path("/foo/").appendPath(Path("/bar")));
        assertEquals("6.13", Path("/foo/bar"), Path("/foo/").appendPath(Path("bar")));
        assertEquals("6.14", Path("foo/bar/"), Path("foo").appendPath(Path("/bar/")));
        assertEquals("6.15", Path("foo/bar/"), Path("foo").appendPath(Path("bar/")));
        assertEquals("6.16", Path("/foo/bar/"), Path("/foo/").appendPath(Path("/bar/")));
        assertEquals("6.17", Path("/foo/bar/"), Path("/foo/").appendPath(Path("bar/")));
        assertEquals("7.0", Path("/foo/bar"), Path("/foo").append("//bar"));
        assertEquals("7.1", Path("/foo/bar/test"), Path("/foo").append("bar//test"));
        assertEquals("7.2", Path("//foo/bar"), Path("//foo").append("bar"));
        assertEquals("7.3", Path("/bar"), Path._ROOT.append("//bar"));
        assertEquals("8.0", fore, fore.appendPath(Path._ROOT));
        assertEquals("8.1", fore, fore.appendPath(Path._EMPTY));
        assertEquals("8.2", fore, fore.appendPath(Path("//")));
        assertEquals("8.3", fore, fore.appendPath(Path("/")));
        assertEquals("8.4", fore, fore.appendPath(Path("")));
        assertEquals("8.5", fore, fore.append("//"));
        assertEquals("8.6", fore, fore.append("/"));
        assertEquals("8.7", fore, fore.append(""));
        if(\iWINDOWS){
            assertEquals("8.8", fore, fore.append("c://"));
            assertEquals("8.9", fore, fore.append("c:/"));
            assertEquals("8.10", fore, fore.append("c:"));
        }
    }
    test shared void testSegmentCount(){
        assertEquals("1.0", 0, Path._ROOT.segmentCount);
        assertEquals("1.1", 0, Path._EMPTY.segmentCount);
        assertEquals("2.0", 1, Path("/first").segmentCount);
        assertEquals("2.1", 1, Path("/first/").segmentCount);
        assertEquals("2.2", 3, Path("/first/second/third/").segmentCount);
        assertEquals("2.3", 3, Path("/first/second/third").segmentCount);
        assertEquals("2.4", 5, Path("/first/second/third/fourth/fifth").segmentCount);
        assertEquals("3.0", 0, Path("//").segmentCount);
        assertEquals("3.1", 1, Path("//first").segmentCount);
        assertEquals("3.2", 1, Path("//first/").segmentCount);
        assertEquals("3.3", 2, Path("//first/second").segmentCount);
        assertEquals("3.4", 2, Path("//first/second/").segmentCount);
    }
    test shared void testCanonicalize(){
        assertEquals("??", "//", Path("///////").string);
        assertEquals("??", "/a/b/c", Path("/a/b//c").string);
        assertEquals("??", "//a/b/c", Path("//a/b//c").string);
        assertEquals("??", "a/b/c/", Path("a/b//c//").string);
        assertEquals("2.0", "/", Path("/./././.").string);
        assertEquals("2.1", "/a/b/c", Path("/a/./././b/c").string);
        assertEquals("2.2", "/a/b/c", Path("/a/./b/c/.").string);
        assertEquals("2.3", "a/b/c", Path("a/./b/./c").string);
        assertEquals("3.0", "/a/b", Path("/a/b/c/..").string);
        assertEquals("3.1", "/", Path("/a/./b/../..").string);
        assertEquals("3.2", "../", Path("../").string);
        assertEquals("3.3", "../", Path("./../").string);
        assertEquals("3.4", "../", Path(".././").string);
        assertEquals("3.5", "..", Path("./..").string);
        assertEquals("3.6", ".", Path(".").string);
    }
    suppressWarnings("deprecation")
    test shared void testConstructors(){
        assertEquals("1.0", "", Path("").string);
        assertEquals("1.1", "/", Path("/").string);
        assertEquals("1.2", "a", Path("a").string);
        assertEquals("1.3", "/a", Path("/a").string);
        assertEquals("1.4", "//", Path("//").string);
        assertEquals("1.5", "/a/", Path("/a/").string);
        assertEquals("1.6", "/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z", Path("/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z").string);
        assertEquals("1.7", "...", Path("...").string);
        assertEquals("1.8", "/a/b/.../c", Path("/a/b/.../c").string);
        variable Path anyPath = Path("/first/second/third");
        assertEquals("2.0", Path._EMPTY, Path(""));
        assertEquals("2.1", Path._ROOT, Path("/"));
        assertEquals("2.2", anyPath, anyPath);
        try {
            if(\iWINDOWS){
                assertEquals("3.0", "D:/foo/abc.txt", Path(JFile("D:\\foo\\abc.txt").toURL().path).string);
                assertEquals("3.1", "D:/", Path(JFile("D:/").toURL().path).string);
            }
        }
        catch (MalformedURLException e) {
            fail("4.99", e);
        }
    }
    test shared void testFirstSegment(){
        assertNull("1.0", Path._ROOT.segment(0));
        assertNull("1.1", Path._EMPTY.segment(0));
        assertEquals("2.0", "a", Path("/a/b/c").segment(0));
        assertEquals("2.1", "a", Path("a").segment(0));
        assertEquals("2.2", "a", Path("/a").segment(0));
        assertEquals("2.3", "a", Path("a/b").segment(0));
        assertEquals("2.4", "a", Path("//a/b").segment(0));
        if(\iWINDOWS){
            assertEquals("2.5", "a", Path("c:a/b").segment(0));
            assertEquals("2.6", "a", Path("c:/a/b").segment(0));
        }
        else {
            assertEquals("2.5", "c:", Path("c:/a/b").segment(0));
            assertEquals("2.6", "c:", Path("c:/a\\b").segment(0));
            assertEquals("2.5", "a", Path("a/c:/b").segment(0));
            assertEquals("2.6", "a\\b", Path("a\\b/b").segment(0));
        }
    }
    test shared void testGetFileExtension(){
        variable Path anyPath = Path("index.html");
        assertEquals("1.0", anyPath.fileExtension, "html");
        assertNull("2.0", Path._ROOT.fileExtension);
        assertNull("2.1", Path._EMPTY.fileExtension);
        assertNull("2.2", Path("index").fileExtension);
        assertNull("2.3", Path("/a/b/c.txt/").fileExtension);
        assertEquals("3.0", "txt", Path("/a/b/c.txt").fileExtension);
        assertEquals("3.1", "txt", Path("/a/b/c.foo.txt").fileExtension);
        assertEquals("3.2", "txt", Path("//a/b/c.foo.txt").fileExtension);
        assertEquals("3.3", "txt", Path("c:/a/b/c.foo.txt").fileExtension);
        assertEquals("3.4", "txt", Path("c:a/b/c.foo.txt").fileExtension);
    }
    test shared void testHasTrailingSeparator(){
        assertTrue("1.0", Path("/first/second/third/").hasTrailingSeparator);
        assertTrue("1.1", Path("//first/second/third/").hasTrailingSeparator);
        assertTrue("1.2", Path("c:/first/second/third/").hasTrailingSeparator);
        assertTrue("1.3", Path("c:first/second/third/").hasTrailingSeparator);
        assertTrue("2.0", !Path("first/second/third").hasTrailingSeparator);
        assertTrue("2.1", !Path._ROOT.hasTrailingSeparator);
        assertTrue("2.2", !Path._EMPTY.hasTrailingSeparator);
        assertTrue("2.3", !Path("//first/second/third").hasTrailingSeparator);
        assertTrue("2.4", !Path("c:/first/second/third").hasTrailingSeparator);
        assertTrue("2.5", !Path("c:first/second/third").hasTrailingSeparator);
        assertTrue("3.0", !Path("/first/").removeLastSegments(1).hasTrailingSeparator);
        assertTrue("3.1", !Path("/first/").removeFirstSegments(1).hasTrailingSeparator);
        assertTrue("3.2", !Path("/").hasTrailingSeparator);
        assertTrue("3.3", !Path("/first/").append("..").hasTrailingSeparator);
        assertTrue("3.4", !Path("/first/").appendPath(Path("..")).hasTrailingSeparator);
        assertTrue("3.5", !Path("/first/../").hasTrailingSeparator);
        assertTrue("3.6", !Path._ROOT.addTrailingSeparator().hasTrailingSeparator);
        assertTrue("3.7", !Path._EMPTY.addTrailingSeparator().hasTrailingSeparator);
    }
    test shared void testIsAbsolute(){
        assertTrue("1.0", Path("/first/second/third").absolute);
        assertTrue("1.1", Path._ROOT.absolute);
        assertTrue("1.2", Path("//first/second/third").absolute);
        if(\iWINDOWS){
            assertTrue("1.3", Path("c:/first/second/third").absolute);
        }
        else {
            assertTrue("1.3", Path("/c:first/second/third").absolute);
        }
        assertTrue("2.0", !Path("first/second/third").absolute);
        assertTrue("2.1", !Path._EMPTY.absolute);
        assertTrue("2.2", !Path("c:first/second/third").absolute);
        if(\iWINDOWS){
            assertTrue("3.0", Path("c://").absolute);
        }
        else {
            assertTrue("3.0", Path("//c:/").absolute);
        }
        assertTrue("3.1", Path("//").absolute);
        assertTrue("3.2", Path("//a").absolute);
        assertTrue("3.3", Path("//a/b/").absolute);
    }
    test shared void testIsEmpty(){
        assertTrue("1.0", Path._EMPTY.emptyPath);
        assertTrue("1.1", Path("//").emptyPath);
        assertTrue("1.2", Path("").emptyPath);
        assertTrue("1.1", Path("c:").emptyPath == \iWINDOWS);
        assertTrue("2.0", !Path("first/second/third").emptyPath);
        assertTrue("2.1", !Path._ROOT.emptyPath);
        assertTrue("2.2", !Path("//a").emptyPath);
        assertTrue("2.3", !Path("c:/").emptyPath);
    }
    test shared void testIsPrefixOf(){
        variable Path prefix = Path("/first/second");
        variable Path path = Path("/first/second/third/fourth");
        assertTrue("1.0", prefix.isPrefixOf(path));
        assertTrue("1.1", !path.isPrefixOf(prefix));
        assertTrue("1.2", !Path("fifth/sixth").isPrefixOf(path));
        assertTrue("2.0", prefix.addTrailingSeparator().isPrefixOf(path));
        assertTrue("3.0", Path._ROOT.isPrefixOf(path));
        assertTrue("3.1", Path._EMPTY.isPrefixOf(path));
        assertTrue("3.2", !path.isPrefixOf(Path._ROOT));
        assertTrue("3.3", !path.isPrefixOf(Path._EMPTY));
    }
    test shared void testIsRoot(){
        assertTrue("1.0", !Path("/first/second").root);
        assertTrue("1.1", !Path._EMPTY.root);
        assertTrue("1.2", !Path("//").root);
        assertTrue("2.0", Path._ROOT.root);
        assertTrue("2.1", Path("/").root);
    }
    test shared void testIsUNC(){
        assertTrue("1.0", !Path._ROOT.isUNC);
        assertTrue("1.1", !Path._EMPTY.isUNC);
        assertTrue("2.0", !Path("a").isUNC);
        assertTrue("2.1", !Path("a/b").isUNC);
        assertTrue("2.2", !Path("/a").isUNC);
        assertTrue("2.3", !Path("/a/b").isUNC);
        assertTrue("3.0", !Path("c:/a/b").isUNC);
        assertTrue("3.1", !Path("c:a/b").isUNC);
        assertTrue("3.2", !Path("/F/../").isUNC);
        assertTrue("4.0", !Path("c://a/").isUNC);
        assertTrue("4.1", !Path("c:\\/a/b").isUNC);
        assertTrue("4.2", !Path("c:\\\\").isUNC);
        assertTrue("5.0", Path("//").isUNC);
        assertTrue("5.1", Path("//a").isUNC);
        assertTrue("5.2", Path("//a/b").isUNC);
        if(\iWINDOWS){
            assertTrue("5.3", Path("\\\\ThisMachine\\HOME\\foo.jar").isUNC);
            assertTrue("6.0", Path("c://a/").withDevice(null).isUNC);
            assertTrue("6.1", Path("c:\\/a/b").withDevice(null).isUNC);
            assertTrue("6.2", Path("c:\\\\").withDevice(null).isUNC);
        }
    }
    test shared void testIsValidPath(){
        variable Path test = Path._ROOT;
        assertTrue("1.0", test.isValidPath("/first/second/third"));
        assertTrue("1.1", test.isValidPath(""));
        assertTrue("1.2", test.isValidPath("a"));
        assertTrue("1.3", test.isValidPath("c:"));
        assertTrue("1.4", test.isValidPath("//"));
        assertTrue("1.5", test.isValidPath("//a"));
        assertTrue("1.6", test.isValidPath("c:/a"));
        assertTrue("1.7", test.isValidPath("c://a//b//c//d//e//f"));
        assertTrue("1.8", test.isValidPath("//a//b//c//d//e//f"));
        if(\iWINDOWS){
            assertTrue("2.1", !test.isValidPath("c:b:"));
            assertTrue("2.2", !test.isValidPath("c:a/b:"));
        }
    }
    test shared void testLastSegment(){
        assertEquals("1.0", "second", Path("/first/second").lastSegment);
        assertEquals("2.0", "first", Path("first").lastSegment);
        assertEquals("2.1", "first", Path("/first/").lastSegment);
        assertEquals("2.2", "second", Path("first/second").lastSegment);
        assertEquals("2.3", "second", Path("first/second/").lastSegment);
        assertNull("3.0", Path._EMPTY.lastSegment);
        assertNull("3.1", Path._ROOT.lastSegment);
        assertNull("3.2", Path("//").lastSegment);
        assertEquals("4.0", "second", Path("//first/second/").lastSegment);
        assertEquals("4.1", "second", Path("//first/second").lastSegment);
        assertEquals("4.2", "second", Path("c:/first/second/").lastSegment);
        assertEquals("4.3", "second", Path("c:first/second/").lastSegment);
        assertEquals("5.0", "first", Path("//first").lastSegment);
        assertEquals("5.1", "first", Path("//first/").lastSegment);
    }
    test shared void testMakeAbsolute(){
        variable Path anyPath = Path("first/second/third").makeAbsolute();
        assertTrue("1.0", anyPath.absolute);
        assertEquals("1.1", Path("/first/second/third"), anyPath);
        anyPath=Path("").makeAbsolute();
        assertTrue("2.0", anyPath.absolute);
        assertEquals("2.1", Path._ROOT, anyPath);
    }
    test shared void testMakeRelative(){
        variable Path anyPath = Path("/first/second/third").makeRelative();
        assertTrue("1.0", !anyPath.absolute);
        assertEquals("1.1", Path("first/second/third"), anyPath);
        anyPath=Path._ROOT.makeRelative();
        assertTrue("2.0", !anyPath.absolute);
        assertEquals("2.1", Path(""), anyPath);
    }
    test shared void testMakeRelativeTo(){
        variable value bases = { Path("/a/"), Path("/a/b") };
        variable value children = { Path("/a/"), Path("/a/b"), Path("/a/b/c") };
        for(b in bases.indexed){
            value i = b.key;
            value base = b.item;
            for(c in children.indexed){
                value j = c.key;
                value child = c.item;
                value result = child.makeRelativeTo(base);
                assertTrue("1.`` i ``,``j``", !result.absolute);
                assertEquals("2.`` i ``,``j``", base.appendPath(result), child);
            }
        }
        variable Path equalBase = Path("/a/b");
        assertEquals("3.1", "", Path("/a/b").makeRelativeTo(equalBase).string);
        assertEquals("3.2", "", Path("/a/b/").makeRelativeTo(equalBase).string);
        assertEquals("3.3", "", equalBase.makeRelativeTo(equalBase).string);
        bases = { Path("/"), Path("/b"), Path("/b/c") };
        children = { Path("/a/"), Path("/a/b"), Path("/a/b/c") };
        for(b in bases.indexed){
            value i = b.key;
            value base = b.item;
            for(c in children.indexed) {
                value j = c.key;
                value child = c.item;
                value result = child.makeRelativeTo(base);
                assertTrue("6.``i``,``j``", !result.absolute);
                assertEquals("7.``i``,``j``", base.appendPath(result), child);
            }
        }
    }
    test shared void testMakeRelativeToWindows(){
        if(!\iWINDOWS) {
            return ;
        }
        value bases = { Path("c:/a/"), Path("c:/a/b") };
        value children = { Path("d:/a/"), Path("d:/a/b"), Path("d:/a/b/c") };
        for(b in bases.indexed) {
            value i = b.key;
            value base = b.item;
            for(c in children.indexed) {
                value j = c.key;
                value child = c.item;
                value result = child.makeRelativeTo(base);
                assertTrue("1.``i``,``j``", result.absolute);
                assertEquals("2.``i``,``j``", child, result);
            }
        }
    }
    test shared void testMakeUNC(){
        value inputs = ArrayList<Path>();
        value expected = ArrayList<String>();
        value expectedNon = ArrayList<String>();
        inputs.add(Path._ROOT);
        expected.add("//");
        expectedNon.add("/");
        inputs.add(Path._EMPTY);
        expected.add("//");
        expectedNon.add("");
        inputs.add(Path("a"));
        expected.add("//a");
        expectedNon.add("a");
        inputs.add(Path("a/b"));
        expected.add("//a/b");
        expectedNon.add("a/b");
        inputs.add(Path("/a/b/"));
        expected.add("//a/b/");
        expectedNon.add("/a/b/");
        inputs.add(Path("//"));
        expected.add("//");
        expectedNon.add("/");
        inputs.add(Path("//a"));
        expected.add("//a");
        expectedNon.add("/a");
        inputs.add(Path("//a/b"));
        expected.add("//a/b");
        expectedNon.add("/a/b");
        inputs.add(Path("//a/b/"));
        expected.add("//a/b/");
        expectedNon.add("/a/b/");
        inputs.add(Path.fromDevice("c:", "/"));
        expected.add("//");
        expectedNon.add("c:/");
        inputs.add(Path.fromDevice("c:", ""));
        expected.add("//");
        expectedNon.add("c:");
        inputs.add(Path.fromDevice("c:", "a"));
        expected.add("//a");
        expectedNon.add("c:a");
        inputs.add(Path.fromDevice("c:", "a/b"));
        expected.add("//a/b");
        expectedNon.add("c:a/b");
        inputs.add(Path.fromDevice("c:", "/a"));
        expected.add("//a");
        expectedNon.add("c:/a");
        inputs.add(Path.fromDevice("c:", "/a/b"));
        expected.add("//a/b");
        expectedNon.add("c:/a/b");
        assertEquals("0.0", inputs.size, expected.size);
        assertEquals("0.1", inputs.size, expectedNon.size);
        for(usecase in zip(inputs, zipPairs(expected, expectedNon))) {
            let ([path, expectedForPath, expectedNonForPath] = usecase);
            variable Path result = path.makeUNC(true);
            assertTrue("1.0.`` path `` (``result``)", result.isUNC);
            assertEquals("1.1.``path``", expectedForPath, result.string);
            result=path.makeUNC(false);
            assertTrue("1.3.``path``", !result.isUNC);
            assertEquals("1.4.``path``", expectedNonForPath, result.string);
        }
    }
    test shared void testRegression(){
        try {
            Path("C:\\/eclipse");
        }
        catch (e) {
            fail("1.0", e);
        }
        try {
            if(\iWINDOWS){
                value path = Path("d:\\\\ive");
                assertTrue("2.0", !path.isUNC);
                assertEquals("2.1", 1, path.segmentCount);
                assertEquals("2.2", "ive", path.segment(0));
            }
        }
        catch (e) {
            fail("2.99", e);
        }
    }
    test shared void testRemoveFirstSegments(){
        assertEquals("1.0", Path("second"), Path("/first/second").removeFirstSegments(1));
        assertEquals("1.1", Path("second/third/"), Path("/first/second/third/").removeFirstSegments(1));
        assertEquals("1.2", Path._EMPTY, Path("first").removeFirstSegments(1));
        assertEquals("1.3", Path._EMPTY, Path("/first/").removeFirstSegments(1));
        assertEquals("1.4", Path("second"), Path("first/second").removeFirstSegments(1));
        assertEquals("1.5", Path._EMPTY, Path("").removeFirstSegments(1));
        assertEquals("1.6", Path._EMPTY, Path._ROOT.removeFirstSegments(1));
        assertEquals("1.7", Path._EMPTY, Path("/first/second/").removeFirstSegments(2));
        assertEquals("1.8", Path._EMPTY, Path("/first/second/").removeFirstSegments(3));
        assertEquals("1.9", Path("third/fourth"), Path("/first/second/third/fourth").removeFirstSegments(2));
        if(\iWINDOWS){
            assertEquals("2.0", Path("c:second"), Path("c:/first/second").removeFirstSegments(1));
            assertEquals("2.1", Path("c:second/third/"), Path("c:/first/second/third/").removeFirstSegments(1));
            assertEquals("2.2", Path("c:"), Path("c:first").removeFirstSegments(1));
            assertEquals("2.3", Path("c:"), Path("c:/first/").removeFirstSegments(1));
            assertEquals("2.4", Path("c:second"), Path("c:first/second").removeFirstSegments(1));
            assertEquals("2.5", Path("c:"), Path("c:").removeFirstSegments(1));
            assertEquals("2.6", Path("c:"), Path("c:/").removeFirstSegments(1));
            assertEquals("2.7", Path("c:"), Path("c:/first/second/").removeFirstSegments(2));
            assertEquals("2.8", Path("c:"), Path("c:/first/second/").removeFirstSegments(3));
            assertEquals("2.9", Path("c:third/fourth"), Path("c:/first/second/third/fourth").removeFirstSegments(2));
        }
        assertEquals("3.0", Path("second"), Path("//first/second").removeFirstSegments(1));
        assertEquals("3.1", Path("second/third/"), Path("//first/second/third/").removeFirstSegments(1));
        assertEquals("3.2", Path._EMPTY, Path("//first/").removeFirstSegments(1));
        assertEquals("3.3", Path._EMPTY, Path("//").removeFirstSegments(1));
        assertEquals("3.4", Path._EMPTY, Path("//first/second/").removeFirstSegments(2));
        assertEquals("3.5", Path._EMPTY, Path("//first/second/").removeFirstSegments(3));
        assertEquals("3.6", Path("third/fourth"), Path("//first/second/third/fourth").removeFirstSegments(2));
    }
    test shared void testRemoveLastSegments(){
        assertEquals("1.0", Path("/first"), Path("/first/second").removeLastSegments(1));
        assertEquals("1.1", Path("//first"), Path("//first/second").removeLastSegments(1));
        assertEquals("1.2", Path("c:/first"), Path("c:/first/second").removeLastSegments(1));
        assertEquals("1.3", Path("c:first"), Path("c:first/second").removeLastSegments(1));
        assertEquals("2.0", Path("/first/second/"), Path("/first/second/third/").removeLastSegments(1));
        assertEquals("2.1", Path("//first/second/"), Path("//first/second/third/").removeLastSegments(1));
        assertEquals("2.2", Path("c:/first/second/"), Path("c:/first/second/third/").removeLastSegments(1));
        assertEquals("2.3", Path("c:first/second/"), Path("c:first/second/third/").removeLastSegments(1));
        assertEquals("3.0", Path._EMPTY, Path("first").removeLastSegments(1));
        assertEquals("3.1", Path._ROOT, Path("/first/").removeLastSegments(1));
        assertEquals("3.2", Path("first"), Path("first/second").removeLastSegments(1));
        assertEquals("4.0", Path._EMPTY, Path("").removeLastSegments(1));
        assertEquals("4.1", Path._ROOT, Path._ROOT.removeLastSegments(1));
        assertEquals("4.2", Path("//"), Path("//").removeLastSegments(1));
    }
    test shared void testRemoveTrailingSeparator(){
        variable Path with = Path("/first/second/third/");
        variable Path without = Path("/first/second/third");
        assertSame("1.0", without, without.removeTrailingSeparator());
        assertEquals("1.1", without, with.removeTrailingSeparator());
        assertTrue("1.2", !with.removeTrailingSeparator().hasTrailingSeparator);
        assertTrue("1.3", !without.hasTrailingSeparator);
        assertEquals("1.4", without.string, with.removeTrailingSeparator().string);
        assertSame("2.0", Path._ROOT, Path._ROOT.removeTrailingSeparator());
        assertEquals("2.1", Path._EMPTY, Path("").removeTrailingSeparator());
        assertEquals("3.0", Path("//"), Path("//").removeTrailingSeparator());
        assertEquals("3.1", Path("//a"), Path("//a").removeTrailingSeparator());
        assertEquals("3.2", Path("//a"), Path("//a/").removeTrailingSeparator());
        assertEquals("3.3", Path("//a/b"), Path("//a/b").removeTrailingSeparator());
        assertEquals("3.4", Path("//a/b"), Path("//a/b/").removeTrailingSeparator());
        assertEquals("4.0", Path("c:"), Path("c:").removeTrailingSeparator());
        assertEquals("4.1", Path("c:/"), Path("c:/").removeTrailingSeparator());
        assertEquals("4.2", Path("c:/a"), Path("c:/a/").removeTrailingSeparator());
        assertEquals("4.3", Path("c:/a/b"), Path("c:/a/b").removeTrailingSeparator());
        assertEquals("4.4", Path("c:/a/b"), Path("c:/a/b/").removeTrailingSeparator());
        assertEquals("5.0", Path("c:a"), Path("c:a/").removeTrailingSeparator());
        assertEquals("5.1", Path("c:a/b"), Path("c:a/b").removeTrailingSeparator());
        assertEquals("5.2", Path("c:a/b"), Path("c:a/b/").removeTrailingSeparator());
    }
    test shared void testSegments(){
        variable Path anyPath;
        variable List<String> segs;
        anyPath=Path("/first/second/third/fourth");
        segs=anyPath.segments;
        assertEquals("1.0", 4, segs.size);
        assertEquals("1.1", "first", segs.get(0));
        assertEquals("1.2", "second", segs.get(1));
        assertEquals("1.3", "third", segs.get(2));
        assertEquals("1.4", "fourth", segs.get(3));
        anyPath=Path("/first/second/");
        segs=anyPath.segments;
        assertEquals("2.0", 2, segs.size);
        assertEquals("2.1", "first", segs.get(0));
        assertEquals("2.2", "second", segs.get(1));
        anyPath=Path("first/second");
        segs=anyPath.segments;
        assertEquals("3.0", 2, segs.size);
        assertEquals("3.1", "first", segs.get(0));
        assertEquals("3.2", "second", segs.get(1));
        anyPath=Path("first");
        segs=anyPath.segments;
        assertEquals("4.0", 1, segs.size);
        assertEquals("4.1", "first", segs.get(0));
        anyPath=Path._EMPTY;
        segs=anyPath.segments;
        assertEquals("5.0", 0, segs.size);
        anyPath=Path._ROOT;
        segs=anyPath.segments;
        assertEquals("6.0", 0, segs.size);
        anyPath=Path("//server/volume/a/b/c");
        segs=anyPath.segments;
        assertEquals("7.0", 5, segs.size);
        assertEquals("7.1", "server", segs.get(0));
        assertEquals("7.2", "volume", segs.get(1));
        assertEquals("7.3", "a", segs.get(2));
        assertEquals("7.4", "b", segs.get(3));
        assertEquals("7.5", "c", segs.get(4));
    }
    test shared void testToString(){
        variable Path anyPath = Path("/first/second/third");
        assertEquals("1.0", "/first/second/third", anyPath.string);
        assertEquals("1.1", "/", Path._ROOT.string);
        assertEquals("1.2", "", Path._EMPTY.string);
    }
    test shared void testUptoSegment(){
        variable Path anyPath = Path("/first/second/third");
        assertEquals("1.0", Path._ROOT, anyPath.uptoSegment(0));
        assertEquals("1.1", Path("/first"), anyPath.uptoSegment(1));
        assertEquals("1.2", Path("/first/second"), anyPath.uptoSegment(2));
        assertEquals("1.3", Path("/first/second/third"), anyPath.uptoSegment(3));
        assertEquals("1.4", Path("/first/second/third"), anyPath.uptoSegment(4));
        anyPath=Path("/first/second/third/");
        assertEquals("2.0", Path._ROOT, anyPath.uptoSegment(0));
        assertEquals("2.1", Path("/first/"), anyPath.uptoSegment(1));
        assertEquals("2.2", Path("/first/second/"), anyPath.uptoSegment(2));
        assertEquals("2.3", Path("/first/second/third/"), anyPath.uptoSegment(3));
        assertEquals("2.4", Path("/first/second/third/"), anyPath.uptoSegment(4));
        anyPath=Path("first/second/third");
        assertEquals("3.0", Path._EMPTY, anyPath.uptoSegment(0));
        assertEquals("3.1", Path("first"), anyPath.uptoSegment(1));
        assertEquals("3.2", Path("first/second"), anyPath.uptoSegment(2));
        assertEquals("3.3", Path("first/second/third"), anyPath.uptoSegment(3));
        assertEquals("3.4", Path("first/second/third"), anyPath.uptoSegment(4));
        anyPath=Path("first/second/third/");
        assertEquals("4.0", Path._EMPTY, anyPath.uptoSegment(0));
        assertEquals("4.1", Path("first/"), anyPath.uptoSegment(1));
        assertEquals("4.2", Path("first/second/"), anyPath.uptoSegment(2));
        assertEquals("4.3", Path("first/second/third/"), anyPath.uptoSegment(3));
        assertEquals("4.4", Path("first/second/third/"), anyPath.uptoSegment(4));
        if(\iWINDOWS){
            anyPath=Path("c:/first/second/third");
            assertEquals("5.0", Path("c:/"), anyPath.uptoSegment(0));
            anyPath=Path("c:/first/second/third/");
            assertEquals("5.1", Path("c:/"), anyPath.uptoSegment(0));
            anyPath=Path("c:first/second/third/");
            assertEquals("5.2", Path("c:"), anyPath.uptoSegment(0));
        }
        anyPath=Path("//one/two/three");
        assertEquals("5.3", Path("//"), anyPath.uptoSegment(0));
        anyPath=Path("//one/two/three/");
        assertEquals("5.4", Path("//"), anyPath.uptoSegment(0));
    }
}
