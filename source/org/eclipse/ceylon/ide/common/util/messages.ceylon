/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
shared object messages {
    shared object bootstrap {
        shared String filesExist => "The Ceylon bootstrap files already exist.";
        shared String overwrite => "Would you like to overwrite them ?";
        shared String title => "Ceylon bootstrap files creation";
        shared String error => "An error occured during the creation of the Ceylon bootstrap files:";
        shared String retry => "Would you like to retry ?";
        shared String success => "The Ceylon bootstrap files have been successfuly created.";
        shared String versionSelection => "Select the version of the bootstrapped distribution:";
    }
}
