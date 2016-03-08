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
        => Builder(Pattern.compile(pattern, Pattern.\iCASE_INSENSITIVE));

List<Replacer> singularizations = ArrayList {
    replace("(equipment|information|species|series|sheep|deer|swine|stuff)").with("$1"),
    replace("(.*p)eople$").with("$1erson"),
    //replace("(.*o)xen$").with("$1x"), 
    replace("(.*c)hildren$").with("$1hild"), 
    replace("(.*f)eet$").with("$1oot"), 
    replace("(.*t)eeth$").with("$1ooth"), 
    replace("(.*g)eese$").with("$1oose"), 
    replace("(.*)ives?$").with("$1ife"), 
    replace("(.*)ves?$").with("$1f"), 
    replace("(.*m)en$").with("$1an"), 
    replace("(.+[aeiou])ys$").with("$1y"), 
    replace("(.+[^aeiou])ies$").with("$1y"), 
    replace("(.+)zes$").with("$1"), 
    replace("(.*[m|l])ice$").with("$1ouse"), 
    replace("(.*)matrices$").with("$1matrix"), 
    replace("(.*)indices$").with("$1index"), 
    replace("(.+[^aeiou])ices$").with("$1ice"), 
    replace("(.*)ices$").with("$1ex"), 
    replace("(.*(octop|vir|hippopotum))i$").with("$1us"), 
    replace("(.+(s|x|sh|ch))es$").with("$1"), 
    replace("(.+)s$").with("$1")
};

List<Replacer> pluralizations = ArrayList {
    replace("(equipment|information|species|series|sheep|deer|swine|stuff)").with("$1"),
    replace("(.*p)erson$").with("$1eople"), 
    //replace("(.*o)x$").with("$1xen"), 
    replace("(.*c)hild$").with("$1hildren"), 
    replace("(.*f)oot$").with("$1eet"), 
    replace("(.*t)ooth$").with("$1eeth"), 
    replace("(.*g)oose$").with("$1eese"), 
    replace("(.*)fe?$").with("$1ves"), 
    replace("(.*m)an$").with("$1en"), 
    replace("(.+[aeiou]y)$").with("$1s"), 
    replace("(.+[^aeiou])y$").with("$1ies"), 
    replace("(.+z)$").with("$1zes"), 
    replace("(.*[m|l])ouse$").with("$1ice"), 
    replace("(.+)(e|i)x$").with("$1ices"), 
    replace("(.*(octop|vir|hippopotum))us$").with("$1i"), 
    replace("(.+(s|x|sh|ch))$").with("$1es"), 
    replace("(.+)").with("$1s")
};

shared String singularize(String word) {
    for (singularization in singularizations) {
        if (singularization.matches(word)) {
            return singularization.replace();
        }
    }
    else {
        return word;
    }
}

shared String pluralize(String word) {
    for (pluralization in pluralizations) {
        if (pluralization.matches(word)) {
            return pluralization.replace();
        }
    }
    else { 
        return word;
    }
}

