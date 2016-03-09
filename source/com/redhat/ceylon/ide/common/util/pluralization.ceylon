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
    Pattern {
        compile,
        i=CASE_INSENSITIVE
    }
}

Pattern pattern(String text) => compile(text,i);

List<[Pattern,String]> singularizations = ArrayList {
    [pattern("(.*(equipment|information|species|series|sheep|deer|swine|stuff|aircraft|offspring))"), "$1"], 
    [pattern("(.*p)eople$"), "$1erson"], 
    //[pattern("(.*o)xen$"), "$1x"],
    [pattern("(.*c)hildren$"), "$1hild"],
    [pattern("(.*f)eet$"), "$1oot"],
    [pattern("(.*t)eeth$"), "$1ooth"],
    [pattern("(.*g)eese$"), "$1oose"],
    [pattern("(.*)ives?$"), "$1ife"],
    [pattern("(.*)ves?$"), "$1f"],
    [pattern("(.*m)en$"), "$1an"],
    [pattern("(.+[aeiou])ys$"), "$1y"],
    [pattern("(.+[^aeiou])ies$"), "$1y"],
    [pattern("(.+)zes$"), "$1"],
    [pattern("(.*[m|l])ice$"), "$1ouse"],
    [pattern("(.*)matrices$"), "$1matrix"],
    [pattern("(.*)indices$"), "$1index"],
    [pattern("(.+[^aeiou])ices$"), "$1ice"],
    [pattern("(.*)ices$"), "$1ex"],
    [pattern("(.*(vir|fung|syllab|nucle|stimul|foc|termin))i$"), "$1us"],
    [pattern("(.*(phenomen|criteri))a$"), "$1on"],
    [pattern("(.*(bacteri|curricul|medi|memorand))a$"), "$1um"],
    //[pattern("(.+)ses"), "$1sis"],
    [pattern("(.+(s|x|sh|ch))es$"), "$1"],
    [pattern("(.+)s$"), "$1"]
};

List<[Pattern,String]> pluralizations = ArrayList {
    [pattern("(.*(equipment|information|species|series|sheep|deer|swine|stuff|aircraft|offspring))"), "$1"], 
    [pattern("(.*p)erson$"), "$1eople"],
    //[pattern("(.*o)x$"), "$1xen"],
    [pattern("(.*c)hild$"), "$1hildren"],
    [pattern("(.*f)oot$"), "$1eet"],
    [pattern("(.*t)ooth$"), "$1eeth"],
    [pattern("(.*g)oose$"), "$1eese"],
    [pattern("(.*)fe?$"), "$1ves"],
    [pattern("(.*m)an$"), "$1en"],
    [pattern("(.+[aeiou]y)$"), "$1s"],
    [pattern("(.+[^aeiou])y$"), "$1ies"],
    [pattern("(.+z)$"), "$1zes"],
    [pattern("(.*[m|l])ouse$"), "$1ice"],
    [pattern("(.+)(e|i)x$"), "$1ices"],
    [pattern("(.*(vir|fung|syllab|nucle|stimul|foc|termin))us$"), "$1i"],
    [pattern("(.*(phenomen|criteri))on$"), "$1a"],
    [pattern("(.*(bacteri|curricul|medi|memorand))um$"), "$1a"],
    [pattern("(.+)sis"), "$1ses"],
    [pattern("(.+(s|x|sh|ch))$"), "$1es"],
    [pattern("(.+)"), "$1s"]
};

String applyPatterns(List<[Pattern, String]> list, String word) {
    for ([pattern,replacement] in list) {
        value matcher = pattern.matcher(javaString(word));
        if (matcher.matches()) {
            return matcher.replaceFirst(replacement);
        }
    }
    else {
        return word;
    }
}

shared String singularize(String word) 
        => applyPatterns(singularizations, word);

shared String pluralize(String word) 
        => applyPatterns(pluralizations, word);

