/*
 * Original code from Mattias Fagerlund
 *
 *   http://lotsacode.wordpress.com/2010/03/05/singularization-pluralization-in-c/
 *
 * and Matt Grande
 *
 *   http://mattgrande.wordpress.com/2009/10/28/pluralization-helper-for-c/
 *
 * Converted Java by Mark Renouf
 *
 *   https://gist.github.com/mrenouf/805745
 * 
 * Converted Ceylon by Gavin King
 *
 */

import ceylon.collection {
    HashSet,
    ArrayList
}
import ceylon.interop.java {
    javaString
}

import java.util.regex {
    Pattern,
    Matcher
}

class Builder(Pattern pattern) {
    shared Replacer with(String replacement) 
            => Replacer(pattern, replacement);
}

class Replacer(Pattern pattern, String replacement) {
    late variable Matcher m;
    shared Boolean matches(String word) {
        m = pattern.matcher(javaString(word));
        return m.matches();
    }
    shared String replace() => m.replaceFirst(replacement);
}

Builder replace(String pattern) 
        => Builder(Pattern.compile(pattern));

Set<String> unpluralizables = HashSet {
    "equipment", 
    "information", 
    //"rice", 
    //"money", 
    "species", 
    "series", 
    //"fish", 
    "sheep", 
    "deer",
    "swine",
    "stuff"
};

List<Replacer> singularizations = ArrayList {
    replace("(.*)people$").with("$1person"),
    replace("oxen$").with("ox"), 
    replace("children$").with("child"), 
    replace("feet$").with("foot"), 
    replace("teeth$").with("tooth"), 
    replace("geese$").with("goose"), 
    replace("(.*)ives?$").with("$1ife"), 
    replace("(.*)ves?$").with("$1f"), 
    replace("(.*)men$").with("$1man"), 
    replace("(.+[aeiou])ys$").with("$1y"), 
    replace("(.+[^aeiou])ies$").with("$1y"), 
    replace("(.+)zes$").with("$1"), 
    replace("([m|l])ice$").with("$1ouse"), 
    replace("matrices$").with("matrix"), 
    replace("indices$").with("index"), 
    replace("(.+[^aeiou])ices$").with("$1ice"), 
    replace("(.*)ices$").with("$1ex"), 
    replace("(octop|vir)i$").with("$1us"), 
    replace("(.+(s|x|sh|ch))es$").with("$1"), 
    replace("(.+)s$").with("$1")
};

List<Replacer> pluralizations = ArrayList {
    replace("(.*)person$").with("$1people"), 
    replace("ox$").with("oxen"), 
    replace("child$").with("children"), 
    replace("foot$").with("feet"), 
    replace("tooth$").with("teeth"), 
    replace("goose$").with("geese"), 
    replace("(.*)fe?$").with("$1ves"), 
    replace("(.*)man$").with("$1men"), 
    replace("(.+[aeiou]y)$").with("$1s"), 
    replace("(.+[^aeiou])y$").with("$1ies"), 
    replace("(.+z)$").with("$1zes"), 
    replace("([m|l])ouse$").with("$1ice"), 
    replace("(.+)(e|i)x$").with("$1ices"), 
    replace("(octop|vir)us$").with("$1i"), 
    replace("(.+(s|x|sh|ch))$").with("$1es"), 
    replace("(.+)").with("$1s")
};

shared String singularize(String word) {
    if (word.lowercased in unpluralizables) {
        return word;
    }
    
    for (singularization in singularizations) {
        if (singularization.matches(word)) {
            return singularization.replace();
        }
    }
    
    return word;
}

shared String pluralize(String word) {
    if (word.lowercased in unpluralizables) {
        return word;
    }
    
    for (pluralization in pluralizations) {
        if (pluralization.matches(word)) {
            return pluralization.replace();
        }
    }
    
    return word;
}
