import ceylon.collection {
    MutableMap
}

import ceylon.language {
    newMap = map
}

shared class ImmutableMapWrapper<Key, Item>(variable Map<Key, Item> immutableMap = emptyMap) satisfies MutableMap<Key, Item> 
        given Key satisfies Object {
    
    shared Map<Key, Item> immutable =>
            synchronize { 
                on = this; 
                function do() => immutableMap;
            };
    
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
    
    "Clears the whole map,
     and returns the previous contents as un immutable map"
    shared actual Map<Key, Item> clear() => synchronize { 
        on = this; 
        function do() {
            value oldMap = immutableMap;
            immutableMap = emptyMap;
            return oldMap;
        }
    };
    
    shared ImmutableMapWrapper<Key, Item> reset({<Key->Item>*} newEntries) => 
            let(do = () {
                if (immutableMap.size != newEntries.size
                    || !immutableMap.keys.containsEvery(newEntries.map((entry) => entry.key))) {
                    immutableMap = newMap(newEntries);
                }
                return this;
            }) synchronize(this, do);
    
    shared ImmutableMapWrapper<Key, Item> resetKeys({Key*} newKeys, Item toItem(Key key), Boolean reuseExistingItems=true) => 
            let(do = () {
                if (immutableMap.size != newKeys.size
                    || !immutableMap.keys.containsEvery(newKeys)) {
                    immutableMap = newMap(newKeys.map((key) => 
                        key -> (
                            if (reuseExistingItems, exists item=immutableMap[key]) 
                            then item 
                            else toItem(key))));
                }
                return this;
            }) synchronize(this, do);

    shared actual Item? put(Key key, Item item) => 
            let(do = () {
                Item? result = immutableMap.get(key);
                immutableMap = newMap(
                    immutableMap.filterKeys((keyToKeep) => 
                        keyToKeep != key).chain { key->item });
                return result;
            }) synchronize(this, do);
            
    shared actual ImmutableMapWrapper<Key, Item> putAll({<Key->Item>*} entries) => 
            let(do = () {
                value keysToPut = set(entries.map((entry) => entry.key));
                immutableMap = newMap(immutableMap
                    .filterKeys((keyToKeep) => ! keyToKeep in keysToPut)
                        .chain(entries));
                return this;
            }) synchronize(this, do);
                    
    shared ImmutableMapWrapper<Key, Item> putAllKeys({Key*} keys, Item toItem(Key key)) => 
            let(do = () {
                immutableMap = newMap(immutableMap
                    .filterKeys((keyToKeep) => ! keyToKeep in keys)
                        .chain(keys.map((key) => key->toItem(key))));
                return this;
            }) synchronize(this, do);

    shared actual Item? remove(Key key)  => 
            let(do = () {
                Item? result = immutableMap.get(key);
                immutableMap = newMap(
                    immutableMap.filterKeys((keyToKeep) => keyToKeep != key));
                return result;
            }) synchronize(this, do);
    
    shared actual ImmutableMapWrapper<Key, Item> removeAll({Key*} keys)  => 
            let(do = () {
                immutableMap = newMap(
                    immutableMap.filterKeys((keyToKeep) => ! keyToKeep in keys));
                return this;
            }) synchronize(this, do);
    
    shared actual String string => immutableMap.string;
}