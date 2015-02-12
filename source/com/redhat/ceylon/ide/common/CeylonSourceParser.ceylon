import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.analyzer {
    ModuleManager
}
import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.model {
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
    FileVirtualFile
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

shared interface CeylonSourceParser<ResultPhasedUnit, NativeResource, NativeFolder, NativeFile> 
        given ResultPhasedUnit satisfies PhasedUnit
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
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
        FileVirtualFile<NativeResource, NativeFolder, NativeFile> file,
        FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir,
        Package pkg)
            => parseSourceCodeToPhasedUnit(moduleManager, 
            InputStreamReader(file.inputStream, charset(file)), 
            pkg);
    
    shared formal ResultPhasedUnit createPhasedUnit(Tree.CompilationUnit cu, Package pkg, List<CommonToken> tokenStream);
    shared formal String charset(FileVirtualFile<NativeResource, NativeFolder, NativeFile> file);
}

shared class ProjectSourceParser<NativeProject, NativeResource, NativeFolder, NativeFile>(
    ceylonProject,
    unitFile,
    srcDir,
    moduleManager, 
    typeChecker)
        satisfies CeylonSourceParser<ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object 
        given NativeResource satisfies Object 
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared CeylonProject<NativeProject> ceylonProject;
    shared FileVirtualFile<NativeResource, NativeFolder, NativeFile> unitFile;
    shared FolderVirtualFile<NativeResource, NativeFolder, NativeFile> srcDir;
    shared IdeModuleManager moduleManager;
    shared TypeChecker typeChecker;
    
    shared actual default ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile> createPhasedUnit(
        Tree.CompilationUnit cu,
        Package pkg,
        List<CommonToken> tokens)
        => ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>(ceylonProject, unitFile, srcDir, cu, pkg, moduleManager, typeChecker, tokens);
            
    shared actual default String charset(FileVirtualFile<NativeResource,NativeFolder,NativeFile> file)
        => file.charset else ceylonProject.defaultCharset;
}
