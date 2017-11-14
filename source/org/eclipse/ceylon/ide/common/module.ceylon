/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
native("jvm")
module org.eclipse.ceylon.ide.common "1.3.4-SNAPSHOT" {
    shared import java.base "7";
    shared import java.compiler "7";
    shared import javax.xml "7";
    shared import ceylon.interop.java "1.3.4-SNAPSHOT";
    shared import ceylon.collection "1.3.4-SNAPSHOT";
    shared import ceylon.formatter "1.3.4-SNAPSHOT";
    shared import org.eclipse.ceylon.typechecker "1.3.4-SNAPSHOT";
    shared import org.eclipse.ceylon.compiler.java "1.3.4-SNAPSHOT";
    shared import org.eclipse.ceylon.compiler.js "1.3.4-SNAPSHOT";
    shared import org.eclipse.ceylon.common "1.3.4-SNAPSHOT";
    shared import org.eclipse.ceylon.tools "1.3.4-SNAPSHOT";
    shared import org.jgrapht.core "0.9.1";
    shared import net.lingala.zip4j "1.3.2";
    import ceylon.bootstrap "1.3.4-SNAPSHOT";
}
