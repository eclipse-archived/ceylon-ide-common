import ceylon.collection {
    MutableMap
}

import ceylon.language {
    newMap = map
}

shared class ImmutableMapWrapper<Key, Item>(variable Map<Key, Item> immutableMap = emptyMap) satisfies MutableMap<Key, Item> 
        given Key satisfies Object {
    
    shared actual MutableMap<Key,Item> clone() => ImmutableMapWrapper(immutableMap);
    
    shared actual Boolean defines(Object key) => immutableMap.defines(key);
    
    shared actual Item? get(Object key) => immutableMap.get(key);
    
    shared actual Iterator<Key->Item> iterator() => immutableMap.iterator();
    
    shared actual Integer hash => immutableMap.hash;
    
    shared actual Boolean equals(Object that) {
        if (is Identifiable that, this === that) {
            return true;
        }
        if (is ImmutableMapWrapper<out Object, out Object> that) {
            return immutableMap==that.immutableMap;
        } else if (is Map<Object, Object> that) {
            return immutableMap==that;
        } else {
            return false;
        }
    }
    
    shared actual void clear() => synchronize { 
        on = this; 
        void do() {
            immutableMap = emptyMap;
        }
    };
    
    shared void reset({<Key->Item>*} newEntries) => synchronize {
        on = this;
        void do() {
            if (immutableMap.size != newEntries.size
                || !immutableMap.keys.containsEvery(newEntries.map((entry) => entry.key))) {
                immutableMap = newMap(newEntries);
            }
        }
    };
    
    shared void resetKeys({Key*} newKeys, Item toItem(Key key)) => synchronize {
        on = this;
        void do() {
            if (immutableMap.size != newKeys.size
                || !immutableMap.keys.containsEvery(newKeys)) {
                immutableMap = newMap(newKeys.map((key) => key->toItem(key)));
            }
        }
    };

    shared actual Item? put(Key key, Item item) => synchronize { 
        on = this;
        function do() {
            Item? result = immutableMap.get(key);
            immutableMap = newMap { key->item,
                *immutableMap.filterKeys((keyToKeep) => keyToKeep != key) };
            return result;
        }
    };
    
    shared actual void putAll({<Key->Item>*} entries) => synchronize { 
        on = this;
        void do() {
            value keysToPut = set(entries.map((entry) => entry.key));
            immutableMap = newMap(immutableMap
                                    .filterKeys((keyToKeep) => ! keyToKeep in keysToPut)
                                    .chain(entries));
            }
        };
        
    shared void putAllKeys({Key*} keys, Item toItem(Key key)) => synchronize { 
        on = this;
        void do() {
            immutableMap = newMap(immutableMap
                .filterKeys((keyToKeep) => ! keyToKeep in keys)
                    .chain(keys.map((key) => key->toItem(key))));
        }
    };

    shared actual Item? remove(Key key)  => synchronize { 
        on = this;
        function do() {
            Item? result = immutableMap.get(key);
            immutableMap = newMap(
                immutableMap.filterKeys((keyToKeep) => keyToKeep != key));
            return result;
        }
    };
    
    shared actual void removeAll({Key*} keys)  => synchronize { 
        on = this;
        void do() {
            immutableMap = newMap(
                immutableMap.filterKeys((keyToKeep) => ! keyToKeep in keys));
        }
    };
    
    shared actual String string => immutableMap.string;
}