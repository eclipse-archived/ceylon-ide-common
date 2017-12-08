/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
shared Boolean equalsWithNulls<OneType, OtherType>(OneType? one, OtherType? other,
        Boolean(OtherType)(OneType) equals = OneType.equals,
        Boolean twoNullsAreEqual = true)
    given OneType satisfies Object
    given OtherType satisfies Object {

    if (exists one, exists other) {
        return equals(one)(other);
    } else {
        return twoNullsAreEqual && one is Null && other is Null;
    }
}