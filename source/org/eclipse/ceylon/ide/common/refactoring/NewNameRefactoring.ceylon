/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.ide.common.util {
    synchronize
}

shared interface NewNameRefactoring {
    shared variable formal String? internalNewName;
    shared default String newName
            => synchronize {
        on = this;
        function do() {
            if (exists n = internalNewName) {
                return n;
            } else {
                internalNewName = initialNewName;
                assert (exists n = internalNewName);
                return n;
            }
        }
    };
    assign newName {
        synchronize {
            on = this;
            void do() {
                internalNewName = newName;
            }
        };
    }
    shared formal String initialNewName;
    shared formal Boolean forceWizardMode;
}

