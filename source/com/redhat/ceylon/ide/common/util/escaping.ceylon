import com.redhat.ceylon.model.typechecker.model {
    Package,
    DeclarationWithProximity,
    Declaration,
    TypedDeclaration,
    TypeDeclaration,
    Unit
}

import java.lang {
    JString=String
}


shared object escaping {
    
    shared {String+} keywords = {"import", "assert",
        "alias", "class", "interface", "object", "given", "value", "assign", "void", "function", 
        "assembly", "module", "package", "of", "extends", "satisfies", "abstracts", "in", "out", 
        "return", "break", "continue", "throw", "if", "else", "switch", "case", "for", "while", 
        "try", "catch", "finally", "this", "outer", "super", "is", "exists", "nonempty", "then",
        "dynamic", "new", "let"};
    
    shared String concatenateKeywords(String delim)
        => delim.join(keywords);
    
    shared Boolean isKeyword(String|JString identifier) 
            => identifier.string in keywords;
    
    shared String escape(String name)
            => if (name in keywords)
                then "\\i``name``"
                else name;
    
    "Escapes inital lowercase identifier.
     
     Provided argument must be legal unescaped identifier. 
     Otherwise result of this method is unspecified."
    shared String escapeInitialLowercase(String name) {
        value first = name.first;
        if (exists first) {
            if (name in keywords || !first.lowercase) {
                return "\\i``name``";
            } else {
                return name;
            }
        } else {
            return "\\i";
        }
    }
    
    "Escapes inital uppercase identifier.
     
     Provided argument must be legal unescaped identifier. 
     Otherwise result of this method is unspecified."
    shared String escapeInitialUppercase(String name) {
        value first = name.first;
        if (exists first) {
            if (!first.uppercase) {
                return "\\I``name``";
            } else {
                return name;
            }
        } else {
            return "\\I";
        }
    }
    
    shared String escapePackageName(Package p) {
        value path = p.name;
        value sb = StringBuilder();
        for (pathPart in path) {
            if (!pathPart.empty) {
                if (!sb.empty) {
                    sb.append(".");
                }
                sb.append(escape(pathPart.string));
            }
        }
        return sb.string;
    }
    
    shared String escapeName(DeclarationWithProximity|Declaration declaration, Unit? unit = null) {
        switch (declaration)
        case (is DeclarationWithProximity) {
            return escapeAliasedName {
                declaration = declaration.declaration;
                aliass = declaration.name;
            };
        }
        case (is Declaration) {
            return escapeAliasedName { 
                declaration = declaration; 
                aliass = if (exists unit) then declaration.getName(unit) else declaration.name; 
            };
        }
    }
    
    shared String escapeAliasedName(Declaration declaration, String? aliass) {
        if (!exists aliass) {
            return "";
        }
        else {
            assert (exists c = aliass.first);
            switch (declaration)
            case (is TypedDeclaration) {
                if (c.uppercase || aliass in keywords) {
                    return "\\i``aliass``";
                }
            }
            case (is TypeDeclaration) {
                if (c.lowercase && !declaration.anonymous) {
                    return "\\I``aliass``";
                }
            }
            else {}
            return aliass;
        }
    }

    shared String toInitialLowercase(String name) 
            => if (exists first = name.first)
            then first.lowercased.string + name.spanFrom(1)
            else name;
    
    shared String toInitialUppercase(String name) 
            => if (exists first = name.first)
            then first.uppercased.string + name.spanFrom(1)
            else name;
}