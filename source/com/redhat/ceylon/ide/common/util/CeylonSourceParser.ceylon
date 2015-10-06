import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.model.typechecker.model {
    Package
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
import com.redhat.ceylon.ide.common.vfs {
    FolderVirtualFile,
    FileVirtualFile,
    BaseFileVirtualFile,
    BaseFolderVirtualFile
}

import java.io {
    Reader,
    InputStreamReader
}
import java.lang {
    RuntimeException
}

import org.antlr.runtime {
    ANTLRStringStream,
    CommonTokenStream,
    RecognitionException,
    CommonToken
}
import java.util {
    List
}
import com.redhat.ceylon.ide.common.model {
    CeylonProject
}
import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit
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
        for (le in CeylonIterable(lexerErrors)) {
            cu.addLexError(le);
        }
        lexerErrors.clear();

        value parserErrors = parser.errors;
        for (pe in CeylonIterable(parserErrors)) {
            cu.addParseError(pe);
        }
        parserErrors.clear();

        assert(is List<CommonToken> tokens = tokenStream.tokens);
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
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared CeylonProject<NativeProject> ceylonProject;
    shared FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile;
    shared FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir;

    shared actual default ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> createPhasedUnit(
        Tree.CompilationUnit cu,
        Package pkg,
        List<CommonToken> tokens)
        => ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(ceylonProject, unitFile, srcDir, cu, pkg,
            ceylonProject.modules.manager,
            ceylonProject.modules.sourceMapper,
            ceylonProject.typechecker,
            tokens);

    shared actual default String charset(BaseFileVirtualFile file)
        => file.charset else ceylonProject.defaultCharset;
}
