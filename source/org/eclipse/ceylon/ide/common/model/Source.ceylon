/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
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