package com.redhat.ceylon.ide.common.model;

public interface TraversalAction<T> {
    void applyOn(T module);
}