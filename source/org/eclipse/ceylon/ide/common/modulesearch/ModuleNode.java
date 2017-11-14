/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
package org.eclipse.ceylon.ide.common.modulesearch;

import java.util.List;

public class ModuleNode {

    private final String name;
    private final List<ModuleVersionNode> versions;

    public ModuleNode(String name, List<ModuleVersionNode> versions) {
        this.name = name;
        this.versions = versions;
    }

    public String getName() {
        return name;
    }

    public List<ModuleVersionNode> getVersions() {
        return versions;
    }

    public ModuleVersionNode getLastVersion() {
        return versions.get(0);
    }

}