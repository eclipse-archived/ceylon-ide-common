import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer,
    CeylonParser
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.compiler.typechecker.util {
    NewlineFixingStringStream
}
import com.redhat.ceylon.ide.common.model {
    ModelAliases
}
import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit,
    TypecheckerAliases
}
import com.redhat.ceylon.ide.common.vfs {
    BaseFileVirtualFile,
    BaseFolderVirtualFile,
    VfsAliases
}
import com.redhat.ceylon.model.typechecker.model {
    Package
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}

import java.io {
    Reader,
    InputStreamReader
}
import java.lang {
    RuntimeException
}
import java.util {
    List
}

import org.antlr.runtime {
    ANTLRStringStream,
    CommonTokenStream,
    RecognitionException,
    CommonToken
}
import com.redhat.ceylon.ide.common.util {
    unsafeCast
}

shared interface CeylonSourceParser<ResultPhasedUnit>
        given ResultPhasedUnit satisfies PhasedUnit {
    shared default CeylonLexer buildLexer(ANTLRStringStream stringStream)
            => CeylonLexer(stringStream);

    shared default CommonTokenStream buildTokenStream(CeylonLexer lexer)
            => CommonTokenStream(lexer);

    shared default CeylonParser buildParser(CommonTokenStream tokenStream)
            => CeylonParser(tokenStream);

    shared ResultPhasedUnit parseSourceCodeToPhasedUnit(
        ModuleManager moduleManager,
        Reader sourceCode,
        Package pkg) {
        ANTLRStringStream input;
        try {
            input = NewlineFixingStringStream.fromReader(sourceCode);
        }
        catch (RuntimeException e) {
            throw e;
        }
        catch (Exception e) {
            throw RuntimeException(e);
        }
        CeylonLexer lexer = buildLexer(input);
        CommonTokenStream tokenStream = buildTokenStream(lexer);

        CeylonParser parser = buildParser(tokenStream);
        Tree.CompilationUnit cu;
        try {
            cu = parser.compilationUnit();
        }
        catch (RecognitionException e) {
            throw RuntimeException(e);
        }

        value lexerErrors = lexer.errors;
        for (le in lexerErrors) {
            cu.addLexError(le);
        }
        lexerErrors.clear();

        value parserErrors = parser.errors;
        for (pe in parserErrors) {
            cu.addParseError(pe);
        }
        parserErrors.clear();

        value tokens = unsafeCast<List<CommonToken>>(tokenStream.tokens);
        return createPhasedUnit(cu, pkg, tokens);
    }

    shared ResultPhasedUnit parseFileToPhasedUnit(
        ModuleManager moduleManager,
        TypeChecker typeChecker,
        BaseFileVirtualFile file,
        BaseFolderVirtualFile srcDir,
        Package pkg)
            => parseSourceCodeToPhasedUnit(moduleManager,
            InputStreamReader(file.inputStream, charset(file)),
            pkg);

    shared formal ResultPhasedUnit createPhasedUnit(Tree.CompilationUnit cu, Package pkg, List<CommonToken> tokenStream);
    shared formal String charset(BaseFileVirtualFile file);
}

shared class ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile>(
    ceylonProject,
    unitFile,
    srcDir)
        satisfies CeylonSourceParser<ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>>
        & ModelAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        & VfsAliases<NativeProject,NativeResource, NativeFolder, NativeFile>

        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared CeylonProjectAlias ceylonProject;
    shared FileVirtualFileAlias unitFile;
    shared FolderVirtualFileAlias srcDir;
    assert(exists modules=ceylonProject.modules);
    
    shared actual default ProjectPhasedUnitAlias createPhasedUnit(
        Tree.CompilationUnit cu,
        Package pkg,
        List<CommonToken> tokens)
        => ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(ceylonProject, unitFile, srcDir, cu, pkg,
            modules.manager,
            modules.sourceMapper,
            modules.manager.typeChecker,
            tokens);

    shared actual default String charset(BaseFileVirtualFile file)
        => ceylonProject.defaultCharset;
}
