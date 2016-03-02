import ceylon.collection {
    ...
}
import ceylon.test {
    ...
}
import com.redhat.ceylon.ide.common.util {
    ImmutableMapWrapper
}
import ceylon.language {
    newMap = map
}

void doTestMap(MutableMap<String,String> map) {
    assertEquals("{}", map.string);
    assertEquals(0, map.size);
    assertTrue(!map.defines("fu"), "a");
    assertEquals(null, map.put("fu", "bar"));
    assertEquals("{ fu->bar }", map.string);
    assertEquals(1, map.size);
    assertTrue(map.defines("fu"), "b");
    assertEquals("bar", map.put("fu", "gee"));
    assertEquals("{ fu->gee }", map.string);
    assertEquals(1, map.size);
    assertTrue(map.defines("fu"), "c");
    map.put("stef", "epardaud");
    assertEquals(2, map.size);
    assertTrue(map.defines("fu"), "d");
    assertTrue(map.defines("stef"), "e");
    assertEquals("epardaud", map["stef"]);
    assertEquals("gee", map["fu"]);
    assertEquals(null, map["bar"]);
    map.clear();
    assertEquals("{}", map.string);
    assertEquals(0, map.size);
    assertTrue(!map.defines("fu"), "f");
    
    function toString(Integer i) => i.string;
    
    // clone test
    for (number in 1..100) {
        map.put(number.string, "#" + number.string);
    }
    value clone = map.clone();
    assertEquals(map, clone);
    map.remove("10");
    assertTrue(map.definesEvery((1..9).map(toString)));
    assertTrue(map.definesEvery((11..100).map(toString)));
    assertFalse(map.defines("10"));
    assertTrue(clone.definesEvery((1..100).map(toString)));
    
    clone.removeAll((60..70).map(toString));
    assertTrue(clone.definesEvery((1..59).map(toString)));
    assertTrue(clone.definesEvery((71..100).map(toString)));
    assertFalse(clone.definesAny((60..70).map(toString)));
    assertTrue(map.definesEvery((11..100).map(toString)));
}

shared test void testMap(){
    doTestMap(ImmutableMapWrapper<String, String>());
}

shared test void testMapEquality() {
    assertEquals(ImmutableMapWrapper(newMap{}), ImmutableMapWrapper(newMap{}));
    assertEquals(ImmutableMapWrapper(newMap{"a"->1, "b"->2}), ImmutableMapWrapper(newMap{"b"->2, "a"->1}));
    assertNotEquals(ImmutableMapWrapper(newMap{"a"->1, "b"->2}), ImmutableMapWrapper(newMap{"b"->2, "a"->2}));
    assertNotEquals(ImmutableMapWrapper(newMap{"a"->1, "b"->2}), ImmutableMapWrapper(newMap{"b"->2}));
    assertNotEquals(ImmutableMapWrapper(newMap{"a"->1, "b"->2}), ImmutableMapWrapper(newMap{}));
    
    assertEquals(naturalOrderTreeMap{"a"->1, "b"->2}, naturalOrderTreeMap{"b"->2, "a"->1});
    assertNotEquals(naturalOrderTreeMap{"a"->1, "b"->2}, naturalOrderTreeMap{"b"->2, "a"->2});
    assertNotEquals(naturalOrderTreeMap{"a"->1, "b"->2}, naturalOrderTreeMap{"b"->2});
    assertNotEquals(naturalOrderTreeMap{"a"->1, "b"->2}, naturalOrderTreeMap{});
    assertEquals(naturalOrderTreeMap{}, naturalOrderTreeMap{});
    
    assertEquals(ImmutableMapWrapper(newMap{}), HashMap{});
    assertEquals(ImmutableMapWrapper(newMap{"a"->1, "b"->2}), HashMap{"b"->2, "a"->1});
}

void doTestMapRemove(MutableMap<String,String> map) {
    assertEquals(map.put("a", "A"), null);
    assertEquals(map.put("b", "B"), null);
    assertEquals(map.put("c", "C"), null);
    assertEquals(map.remove("A"), null);
    assertEquals(map.remove("WHATEVER"), null);
    assertEquals(map.remove("a"), "A");
    assertEquals(map.size, 2);
    assertEquals(map["b"], "B" );
    assertEquals(map["c"], "C" );
    assertEquals(map.remove("a"), null);
    assertEquals(map.remove("b"), "B");
    assertEquals(map.size, 1);
    assertEquals(map["b"], null );
    assertEquals(map["c"], "C" );
    assertEquals(map.put("d", "D"), null);
    assertEquals(map["a"], null );
    assertEquals(map["b"], null );
    assertEquals(map["c"], "C" );
    assertEquals(map["d"], "D" );
    assertEquals(map.size, 2);
    assertEquals(map.remove("b"), null);
    assertEquals(map.remove("c"), "C");
    assertEquals(map.remove("d"), "D");
    assertEquals(map["a"], null );
    assertEquals(map["b"], null );
    assertEquals(map["c"], null );
    assertEquals(map["d"], null );
    assertEquals(map.size, 0);
}

shared test void testMapRemove(){
    doTestMapRemove(ImmutableMapWrapper<String,String>());
}

shared test void testMapConstructor(){
    Map<String,String> map = ImmutableMapWrapper(newMap{"a"->"b", "c"->"d"});
    assertEquals(2, map.size);
    assertEquals("b", map["a"]);
    assertEquals("d", map["c"]);
}

shared test void testMap2(){
    MutableMap<String,String|Integer> map = ImmutableMapWrapper<String,String|Integer>();
    map.put("gravatar_id", "a38479e9dc888f68fb6911d4ce05d7cc");
    map.put("url", "https://api.github.com/users/ceylon");
    map.put("avatar_url", "https://secure.gravatar.com/avatar/a38479e9dc888f68fb6911d4ce05d7cc?d=https://a248.e.akamai.net/assets.github.com%2Fimages%2Fgravatars%2Fgravatar-orgs.png");
    map.put("id", 579261);
    map.put("login", "ceylon");
    assertEquals(5, map.size);
    assertEquals(5, map.keys.size);
    assertEquals(5, map.items.size);
}

shared test void testMapDefines() {
    value entries = {
        "ceylon.math" -> 0,
        "ceylon.net" -> 0,
        "ceylon.process" -> 0,
        "ceylon.unicode" -> 0,
        "com.redhat.ceylon.test" -> 0,
        "test.ceylon.dbc" -> 0,
        "test.ceylon.file" -> 0,
        "test.ceylon.interop.java" -> 0,
        "test.ceylon.io" -> 0,
        "test.ceylon.math" -> 0,
        "test.ceylon.net" -> 0,
        "test.ceylon.process" -> 0,
        "test.ceylon.test" -> 0
    };
    value map = ImmutableMapWrapper(newMap(entries));
    for (entry in entries) {
        assert(map.defines(entry.key));
    }
}

test shared void testMapClone() {
    value map = ImmutableMapWrapper( newMap {1->"foo", 2->"bar"} );
    assertEquals(map, map.clone());
    assertEquals(map.clone().size, 2);
    assertEquals(map.clone().string, "{ 1->foo, 2->bar }");
    assertEquals([for (e in map.clone()) e], [1->"foo", 2->"bar"]);
}

test shared void testMapBug301(){
    value map = ImmutableMapWrapper<String, String>();
    map.put("a", "a");
    map.put("b", "b");
    map.remove("a");
    assertEquals(map.size, 1);
    assertEquals({ for (item in map) item }.sequence(), ["b"->"b"]);
}