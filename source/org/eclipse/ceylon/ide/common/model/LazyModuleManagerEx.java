package org.eclipse.ceylon.ide.common.model;

import org.eclipse.ceylon.model.loader.AbstractModelLoader;

public interface LazyModuleManagerEx {
    void initModelLoader(AbstractModelLoader modelLoader);
}
