shared class Language {
    String languageString;
    [String+] extensions;
    
    shared new(String languageString, [String+] extensions) {
        this.languageString = languageString;
        this.extensions = extensions;
    }
    shared new ceylon {
        languageString = "Ceylon";
        extensions = [".ceylon"];
    }
    shared new java {
        languageString = "Java";
        extensions = [".java"];
    }
    shared new javascript {
        languageString = "Javascript";
        extensions = [".js"];
    }
}

shared interface Source {
    shared formal Language language;
}