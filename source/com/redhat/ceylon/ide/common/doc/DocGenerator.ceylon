import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.completion {
    getDocDescriptionFor,
    getInitialValueDescription
}
import com.redhat.ceylon.ide.common.imports {
    moduleImportUtil
}
import com.redhat.ceylon.ide.common.model {
    CeylonUnit,
    BaseCeylonProject
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    equalsWithNulls
}
import com.redhat.ceylon.model.cmr {
    JDKUtils
}
import com.redhat.ceylon.model.loader {
    LanguageAnnotation
}
import com.redhat.ceylon.model.loader.mirror {
    AnnotatedMirror,
    AnnotationMirror
}
import com.redhat.ceylon.model.loader.model {
    LazyClass,
    LazyInterface,
    LazyClassAlias,
    LazyInterfaceAlias,
    LazyValue,
    LazyFunction,
    LazyTypeAlias,
    JavaBeanValue,
    JavaMethod
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Declaration,
    Package,
    Module,
    Scope,
    Unit,
    FunctionOrValue,
    TypeDeclaration,
    Value,
    TypedDeclaration,
    Class,
    Interface,
    ModelUtil,
    Reference,
    Type,
    Functional,
    Parameter,
    ClassOrInterface,
    TypeParameter,
    Constructor,
    Function,
    NothingType,
    Annotated,
    ModuleImport
}
import com.redhat.ceylon.model.typechecker.util {
    TypePrinter
}

import java.lang {
    JCharacter=Character {
        ...
    }
}
import java.util {
    Collections,
    ArrayList,
    JList=List
}
import com.redhat.ceylon.compiler.typechecker.parser {
    CeylonLexer
}

shared abstract class Icon() of annotations {}
shared object annotations extends Icon() {}

shared String convertToHTML(String content)
        => content.replace("&", "&amp;")
                  .replace("\"", "&quot;")
                  .replace("<", "&lt;")
                  .replace(">", "&gt;");

shared interface DocGenerator {

    shared alias IdeComponent => LocalAnalysisResult;
    
    shared formal String buildLink(Referenceable|String model, String text,
        String protocol = "doc");
    shared formal TypePrinter printer;
    shared formal TypePrinter verbosePrinter;
    shared formal String color(Object? what, Colors how);
    shared formal String markdown(String text, IdeComponent cmp,
        Scope? linkScope = null, Unit? unit = null);
    shared formal void addIconAndText(StringBuilder builder,
        Icons|Referenceable icon, String text);
    shared formal String highlight(String text, IdeComponent cmp);
    shared formal void appendJavadoc(Declaration model, StringBuilder buffer);
    shared formal Boolean showMembers;
    shared formal void appendPageProlog(StringBuilder builder);
    shared formal void appendPageEpilog(StringBuilder builder);
    shared formal String? getLiveValue(Declaration dec, Unit unit);
    shared formal Boolean supportsQuickAssists;
    
    shared Referenceable? getLinkedModel(String? target, IdeComponent cmp) {
        if (exists target,
            exists lastCompilationUnit = cmp.lastCompilationUnit,
            exists typechecker = cmp.typeChecker) {
            if (target.startsWith("doc:ceylon.language/")
             && target.endsWith("/ceylon.language/Nothing")) {
                return lastCompilationUnit.unit.nothingDeclaration;
            }
            return getLinkedModelInternal(target, typechecker);
        }
        else {
            return null;
        }
    }
    
    function targetScope(Referenceable current) {
        Scope scope;
        switch (current)
        case (is Scope) {
            scope = current;
        }
        else case (is TypedDeclaration) {
            scope = current.type.declaration;
        }
        else {
            return null;
        }

        return
            if (is Value scope,
                scope.typeDeclaration.anonymous)
            then scope.typeDeclaration
            else scope;
    }

    Referenceable? getLinkedModelInternal(String link, TypeChecker typeChecker) {
        value [protocol, *maybeAddress]
                = link.split { ':'.equals; limit=1; }.sequence();
        if (exists address = maybeAddress[0]) {
            value bits = address.split('/'.equals).sequence();
            value moduleName = bits[0];
            value moduleVersion = bits[1];
            if (exists moduleVersion) {
                Module linkedModule;
                for (candidate in typeChecker.context.modules.listOfModules) {
                    if (candidate.nameAsString == moduleName &&
                        candidate.version == moduleVersion) {
                        linkedModule = candidate;
                        break;
                    }
                } else {
                    return null;
                }

                if (exists packageName = bits[2],
                    exists linkedPackage
                            = linkedModule.getPackage(packageName)) {
                    variable Referenceable target = linkedPackage;
                    for (bit in bits[3...]) {
                        if (exists scope = targetScope(target),
                            exists member = scope.getDirectMember(bit, null, false)) {
                            target = member;
                        } else {
                            return null;
                        }
                    }
                    return target;
                } else {
                    return linkedModule;
                }
            }
        }

        return null;

    }
    
    function isDocAnnotation(Tree.StringLiteral node) {
        value type = node.token.type;
        return type==CeylonLexer.astringLiteral
            || type==CeylonLexer.averbatimString;
    }

    // see getHoverText(CeylonEditor editor, IRegion hoverRegion)
    shared String? getDocumentation(Tree.CompilationUnit rootNode,
        Integer offset, IdeComponent cmp, String? selection = null)
            => switch (node = getHoverNode(rootNode, offset))
            case (null) null
            case (is Tree.LocalModifier) getInferredTypeText(node)
            case (is Tree.StringLiteral)
                if (isDocAnnotation(node),
                    exists model = nodes.findDeclaration(rootNode, node)?.declarationModel)
                then getDocumentationText(model, node, rootNode, cmp)
                else getTermTypeText(node, selection)
            else case (is Tree.Literal) getTermTypeText(node, selection)
            else if (exists model = nodes.getReferencedDeclaration(node))
                then getDocumentationText(model, node, rootNode, cmp)
                else null;
    
    // see SourceInfoHover.getHoverNode(IRegion, CeylonParseController)
    Node? getHoverNode(Tree.CompilationUnit rootNode, Integer offset) 
            => nodes.findNode(rootNode, null, offset);
    
    // see getInferredTypeHoverText(Node node, IProject project)
    String? getInferredTypeText(Tree.LocalModifier node) {
        if (exists type = node.typeModel) {
            value builder = StringBuilder();
            appendPageProlog(builder);
            appendTypeInfo(builder, "Inferred&nbsp;type", node.unit, type);
            builder.append("<br/>");
            if (supportsQuickAssists, !type.containsUnknowns()) {
                builder.append("One quick assist available:<br/>");
                value link = buildLink(node.startIndex.string,
                    "Specify explicit type", "stp");
                addIconAndText(builder, Icons.quickAssists, link);
            }
            appendPageEpilog(builder);
            return builder.string;
        }
        
        return null;
    }
    
    void appendTypeInfo(StringBuilder builder,
        String description, Unit unit, Type type) {
        value abbreviated 
                = printer.print(type, unit);
        value unabbreviated 
                = verbosePrinter.print(type, unit);
        value simplified 
                = printer.print(unit.denotableType(type), unit);
        addIconAndText(builder, Icons.types, 
            "``description``&nbsp;<tt>``printer.print(type, unit)``</tt> ");
        if (abbreviated!=unabbreviated) {
            builder.append("<p>Abbreviation&nbsp;of&nbsp;")
                    .append(unabbreviated)
                    .append("</p>");
        }
        
        if (simplified!=unabbreviated &&
            simplified!=abbreviated) {
            builder.append("<p>Simplifies&nbsp;to&nbsp;")
                    .append(simplified)
                    .append("</p>");
        }
    }

    
    //see getTermTypeHoverText(Node, String, IDocument doc, IProject project)        
    shared String? getTermTypeText(Tree.Term? term, String? selection = null) {
        if (exists term, exists type = term.typeModel) {
            value builder = StringBuilder();
            
            appendPageProlog(builder);
            value desc = 
                    if (is Tree.Literal term) 
                    then "Literal&nbsp;of&nbsp;type" 
                    else "Expression&nbsp;of&nbsp;type";
            appendTypeInfo(builder, desc, term.unit, type);

            switch (term)
            case (is Tree.StringLiteral) {
                appendStringInfo(term, builder);
                if (exists selection, selection.size==1) {
                    appendCharacterInfo(selection, builder);
                }
            }
            case (is Tree.CharLiteral) {
                if (term.text.size>2) {
                    appendCharacterInfo(term.text[1..1], builder);
                }
            }
            case (is Tree.NaturalLiteral) {
                appendIntegerInfo(term, builder);
            }
            case (is Tree.FloatLiteral) {
                appendFloatInfo(term, builder);
            }
            else {}
            
            appendPageEpilog(builder);
            return builder.string;
        }
        
        return null;
    }
    
    String escape(String content) 
            => content
                .replace("\0", "\\0")
                .replace("\b", "\\b")
                .replace("\t", "\\t")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\f", "\\f")
                .replace("\{#001b}", "\\e");

    void appendStringInfo(Tree.StringLiteral term, StringBuilder builder) {
        value text = 
                if (term.text.shorterThan(250))
                then escape(term.text)
                else escape(term.text[...250]) + "...";
        value html = 
                convertToHTML(text)
                    .replace("\\n", "<br/>");
        builder.append("<br/>");
        builder.append(color("\"``html``\"", Colors.strings)); 
    }
    
    void appendIntegerInfo(Tree.NaturalLiteral term, StringBuilder builder) {
        value text = term.text.replace("_", "");
        if (is Integer int
                = switch (text.first)
                case ('#') Integer.parse(text[1...], 16)
                case ('$') Integer.parse(text[1...], 2)
                else Integer.parse(text)) {
            builder.append("<br/>");
            builder.append(color(int, Colors.numbers));
        }
    }
    
    void appendFloatInfo(Tree.FloatLiteral term, StringBuilder builder) {
        value text = term.text.replace("_", "");
        value float = Float.parse(text);
        builder.append("<br/>");
        builder.append(color(float, Colors.numbers));
    }
    
    // see appendCharacterHoverInfo(StringBuilder buffer, String character)
    void appendCharacterInfo(String text, StringBuilder builder) {
        value html = convertToHTML(escape(text));
        builder.append("<br/>")
            .append(color("'``html``'", Colors.strings));
        
        assert (exists codepoint = text.first?.integer);
        builder.append("<br/>Unicode name: <code>")
                .append(JCharacter.getName(codepoint))
                .append("</code>");
        builder.append("<br/>Codepoint: <code>U+")
                .append(Integer.format(codepoint, 16)
                        .uppercased.padLeading(4, '0'))
                .append("</code>");
        builder.append("<br/>General Category: <code>")
                .append(getCodepointGeneralCategoryName(codepoint))
                .append("</code>");
        builder.append("<br/>Script: <code>")
                .append(UnicodeScript.\iof(codepoint).name())
                .append("</code>");
        builder.append("<br/>Block: <code>")
                .append(UnicodeBlock.\iof(codepoint).string)
                .append("</code><br/>");
    }
    
    // see getCodepointGeneralCategoryName(int codepoint)
    String getCodepointGeneralCategoryName(Integer codepoint)
            => let (t = JCharacter.getType(codepoint).byte)
                 // we can't use a switch, see https://github.com/ceylon/ceylon-spec/issues/938 
                 if (t == combiningSpacingMark)
                    then "Mark, combining spacing"
            else if (t == connectorPunctuation)
                    then "Punctuation, connector"
            else if (t == control)
                    then "Other, control"
            else if (t == currencySymbol)
                    then "Symbol, currency"
            else if (t == dashPunctuation)
                    then "Punctuation, dash"
            else if (t == decimalDigitNumber)
                    then "Number, decimal digit"
            else if (t == enclosingMark)
                    then "Mark, enclosing"
            else if (t == endPunctuation)
                    then "Punctuation, close"
            else if (t == finalQuotePunctuation)
                    then "Punctuation, final quote"
            else if (t == format)
                    then "Other, format"
            else if (t == initialQuotePunctuation)
                    then "Punctuation, initial quote"
            else if (t == letterNumber)
                    then "Number, letter"
            else if (t == lineSeparator)
                    then "Separator, line"
            else if (t == lowercaseLetter)
                    then "Letter, lowercase"
            else if (t == mathSymbol)
                    then "Symbol, math"
            else if (t == modifierLetter)
                    then "Letter, modifier"
            else if (t == modifierSymbol)
                    then "Symbol, modifier"
            else if (t == nonSpacingMark)
                    then "Mark, nonspacing"
            else if (t == otherLetter)
                    then "Letter, other"
            else if (t == otherNumber)
                    then "Number, other"
            else if (t == otherPunctuation)
                    then "Punctuation, other"
            else if (t == otherSymbol)
                    then "Symbol, other"
            else if (t == paragraphSeparator)
                    then "Separator, paragraph"
            else if (t == privateUse)
                    then "Other, private use"
            else if (t == spaceSeparator)
                    then "Separator, space"
            else if (t == startPunctuation)
                    then "Punctuation, open"
            else if (t == surrogate)
                    then "Other, surrogate"
            else if (t == titlecaseLetter)
                    then "Letter, titlecase"
            else if (t == unassigned)
                    then "Other, unassigned"
            else if (t == uppercaseLetter)
                    then "Letter, uppercase"
            else "&lt;Unknown&gt;";


    // see getDocumentationHoverText(Referenceable, CeylonEditor editor, Node node)
    shared String? getDocumentationText(Referenceable model, Node? node,
        Tree.CompilationUnit rootNode, IdeComponent cmp)
            => switch (model)
            case (is Declaration) getDeclarationDoc(model, node, rootNode.unit, cmp, null)
            case (is Package) getPackageDoc(model, cmp)
            case (is Module) getModuleDoc(model, cmp)
            else null;

    // see getDocumentationFor(CeylonParseController, Declaration, Node, Reference)
    shared String getDeclarationDoc(Declaration model, Node? node,
        Unit unit, IdeComponent cmp, Reference? pr) {
        
        variable value decl = model;
        if (is FunctionOrValue model,
            exists typeDecl = model.typeDeclaration, 
            typeDecl.anonymous, !model.type.typeConstructor) {
            decl = typeDecl;
        }
        
        value builder = StringBuilder();
        appendPageProlog(builder);

        addMainDescription(builder, decl, node, pr, cmp, unit);
        value isObj = addInheritanceInfo(decl, node, pr, builder, unit);
        if (!decl is NothingType) {
            addPackageInfo(decl, builder);
        }
        addContainerInfo(decl, pr, node, builder);
        value hasDoc = addDoc(decl, node, builder, cmp);
        addRefinementInfo(decl, pr, node, builder, hasDoc, unit, cmp);
        addReturnType(decl, builder, node, pr, isObj, unit);
        addParameters(cmp, decl, node, pr, builder, unit);
        if (showMembers) {
            addClassMembersInfo(decl, builder);
        }
        if (decl is NothingType) {
            addNothingTypeInfo(builder);
        } else {
            addUnitInfo(decl, builder);
        }
        
        appendPageEpilog(builder);
        
        return builder.string;
    }

    // see getDocumentationFor(CeylonParseController controller, Package pack)
    String getPackageDoc(Package pack, IdeComponent cmp) {
        value builder = StringBuilder();
        
        appendPageProlog(builder);
        addMainPackageDescription(pack, builder, cmp);
        addPackageDocumentation(pack, builder, cmp);
        addAdditionalPackageInfo(pack, builder);
        if (showMembers) {
            addPackageMembers(pack, builder);
        }
        addPackageModuleInfo(pack, builder);
        appendPageEpilog(builder);
        
        return builder.string;
    }
    
    // see addMainPackageDescription(Package pack, StringBuilder buffer)
    void addMainPackageDescription(Package pack, 
        StringBuilder builder, IdeComponent cmp) {
        
        if (pack.shared) {
            addIconAndText(builder, Icons.annotations,
                "<tt>``color("shared ", Colors.annotations)``</tt>");
        }

        addIconAndText(builder, pack,
            "<tt>``highlight("package ``pack.nameAsString``", cmp)``</tt>");
    }
    
    // see addPackageDocumentation(CeylonParseController, Package, StringBuilder)
    void addPackageDocumentation(Package pack, 
        StringBuilder builder, IdeComponent cmp) {
        if (is CeylonUnit unit = pack.unit,
            exists pu = unit.phasedUnit,
            !pu.compilationUnit.packageDescriptors.empty,
            exists refnode = pu.compilationUnit.packageDescriptors[0]) {
            
            appendDocAnnotationContent(pack, refnode.annotationList, builder, pack, cmp);
            appendThrowAnnotationContent(pack, refnode.annotationList, builder, pack, cmp);
            appendSeeAnnotationContent(pack, refnode.annotationList, builder, cmp);
        }
    }
    
    // see addAdditionalPackageInfo(StringBuilder buffer, Package pack)
    void addAdditionalPackageInfo(Package pack, StringBuilder builder) {
        value mod = pack.\imodule;
        if (mod.java) {
            builder.append("<p>This package is implemented in Java.</p>\n");
        }
        if (JDKUtils.isJDKModule(mod.nameAsString)) {
            builder.append("<p>This package forms part of the Java SDK.</p>\n");             
        }
    }
    
    // see void addPackageMembers(StringBuilder buffer, Package pack)
    void addPackageMembers(Package pack, StringBuilder buffer) {
        variable Boolean first = true;
        
        for (dec in pack.members) {
            if (!dec.name exists) {
                continue;
            }
            if (is Class dec, dec.overloaded) {
                continue;
            }
            if (dec.shared, !dec.anonymous) {
                if (first) {
                    buffer.append("<p>Contains:&nbsp;");
                    first = false;
                } else {
                    buffer.append(", ");
                }
                
                buffer.append("<tt>").append(
                    buildLink(dec, dec.nameAsString)).append("</tt>");
            }
        }
        if (!first) {
            buffer.append(".</p>");
        }
    }

    void addModuleDependencies(Module mod, 
        StringBuilder builder, IdeComponent cmp) {
        for (imp in mod.imports) {
            addImportDescription(imp, builder, cmp);
        }
    }
    
    // see getDocumentationFor(CeylonParseController controller, Module mod)
    String? getModuleDoc(Module mod, IdeComponent cmp) {
        value builder = StringBuilder();
        
        appendPageProlog(builder);
        addMainModuleDescription(mod, builder, cmp);
        addAdditionalModuleInfo(mod, builder);
        addModuleDocumentation(mod, builder, cmp);
        addModuleDependencies(mod, builder, cmp);
        addModuleMembers(mod, builder);
        appendPageEpilog(builder);

        return builder.string;
    }

    // see void addMainModuleDescription(Module mod, StringBuilder buffer)
    void addMainModuleDescription(Module mod, 
        StringBuilder buffer, IdeComponent cmp) {
        value buf = StringBuilder();
        if (mod.native) {
            buf.append("native");
        }

        value nativeBackends = mod.nativeBackends;
        if (!nativeBackends.none(), 
            !nativeBackends.header()) {
            value buf2 = StringBuilder();
            moduleImportUtil.appendNativeBackends(buf2, nativeBackends);
            buf.append("(")
                .append(color(buf2.string, Colors.annotationStrings))
                .append(")");
        }
        
        if (mod.native) {
            buf.append("&nbsp;");
        }
        
        if (!buf.empty) {
            value desc = "<tt>``color(buf.string, Colors.annotations)``</tt>";
            addIconAndText(buffer, Icons.annotations, desc);
        }

        value description 
                = "module ``mod.nameAsString`` \"``mod.version``\"";
        buffer.append("<tt>");
        addIconAndText(buffer, mod, highlight(description, cmp));
        buffer.append("</tt>");
    }

    void addImportDescription(ModuleImport imp, 
        StringBuilder buffer, IdeComponent cmp) {
        /*value buf = StringBuilder();
        if (imp.export) {
            buf.append("shared&nbsp;");
        }
        if (imp.optional) {
            buf.append("optional&nbsp;");
        }
        
        if (imp.native) {
            buf.append("native");
        }
        
        value nativeBackends = imp.nativeBackends;
        if (!nativeBackends.none(), !Backends.header == nativeBackends) {
            value buf2 = StringBuilder();
            moduleImportUtil.appendNativeBackends(buf2, nativeBackends);
            buf.append("(")
                    .append(color(buf2.string, Colors.annotationStrings))
                    .append(")");
        }
        
        if (imp.native) {
            buf.append("&nbsp;");
        }*/
        
        value mod = imp.\imodule;
        if (!mod.nameAsString.empty && mod.nameAsString!="default") {
            //value label = "<span>Depends on&nbsp;``color(buf.string, Colors.annotations)````color("import", Colors.keywords)`` ``buildLink(mod, mod.nameAsString)``"
            value label 
                    = "<span>``imp.export then "Exports" else "Imports"``&nbsp;``buildLink(mod, mod.nameAsString)``"
                    + "&nbsp;<tt>``color("\"" + mod.version + "\"", Colors.strings)``</tt>.</span>";
            addIconAndText(buffer, Icons.imports, label);
        }
        
    }
    
    // see addAdditionalModuleInfo(StringBuilder buffer, Module mod)
    void addAdditionalModuleInfo(Module mod, StringBuilder buffer) {
        if (mod.java) {
            buffer.append("<p>This module is implemented in Java.</p>");
        }
        if (mod.defaultModule) {
            buffer.append("<p>The default module for packages which do not
                           belong to explicit module.</p>");
        }
        if (JDKUtils.isJDKModule(mod.nameAsString)) {
            buffer.append("<p>This module forms part of the Java SDK.</p>");            
        }
    }

    // see addModuleDocumentation(CeylonParseController, Module, StringBuilder)
    void addModuleDocumentation(Module mod, 
        StringBuilder buffer, IdeComponent cmp) {
        if (is CeylonUnit unit=mod.unit, 
            exists pu = unit.phasedUnit,
            !pu.compilationUnit.moduleDescriptors.empty,
            exists refnode = pu.compilationUnit.moduleDescriptors[0]) {
            
            value linkScope = mod.getPackage(mod.nameAsString);
            appendDocAnnotationContent(mod, refnode.annotationList, buffer, linkScope, cmp);
            appendThrowAnnotationContent(mod, refnode.annotationList, buffer, linkScope, cmp);
            appendSeeAnnotationContent(mod, refnode.annotationList, buffer, cmp);
        }
    }
    
    // see addModuleMembers(StringBuilder buffer, Module mod)
    void addModuleMembers(Module mod, StringBuilder buffer) {
        variable Boolean first = true;
        
        for (pack in mod.packages) {
            if (pack.shared) {
                if (first) {
                    buffer.append("<p>Contains:&nbsp;");
                    first = false;
                }
                else {
                    buffer.append(", ");
                }

                buffer.append("<tt>").append(
                    buildLink(pack, pack.nameAsString)).append("</tt>");
            }
        }

        if (!first) {
            buffer.append(".</p>");
        }
    }
    
    void addMainDescription(StringBuilder builder, 
        Declaration decl, Node? node, Reference? pr, 
        IdeComponent cmp, Unit unit) {
        
        value annotationsBuilder = StringBuilder();
        if (decl.shared) {
            annotationsBuilder.append("shared&nbsp;");
        }
        if (decl.static) {
            annotationsBuilder.append("static&nbsp;");
        }
        if (decl.actual) {
            annotationsBuilder.append("actual&nbsp;");
        }
        if (decl.default) {
            annotationsBuilder.append("default&nbsp;");
        }
        if (decl.formal) {
            annotationsBuilder.append("formal&nbsp;");
        }
        if (is Value decl, decl.late) {
            annotationsBuilder.append("late&nbsp;");
        }
        if (is FunctionOrValue decl, decl.small) {
            annotationsBuilder.append("small&nbsp;");
        }
        if (is TypedDeclaration decl, decl.variable) {
            annotationsBuilder.append("variable&nbsp;");
        }
        if (decl.native) {
            annotationsBuilder.append("native");
        }
        if (exists backends = decl.nativeBackends, 
            !backends.none(),
            !backends.header()) {
            
            value buf = StringBuilder();
            moduleImportUtil.appendNativeBackends(buf, backends);
            annotationsBuilder
                .append("(")
                .append(color(buf.string, Colors.annotationStrings))
                .append(")");
        }
        if (decl.native) {
            annotationsBuilder.append("&nbsp;");
        }
        if (is TypeDeclaration decl) {
            if (decl.sealed) {
                annotationsBuilder.append("sealed&nbsp;");
            }
            if (decl.final, !decl is Constructor) {
                annotationsBuilder.append("final&nbsp;");
            }
            if (is Class decl, decl.abstract) {
                annotationsBuilder.append("abstract&nbsp;");
            }
        }
        if (decl.annotation) {
            annotationsBuilder.append("annotation&nbsp;");
        }
        
        if (!annotationsBuilder.empty) {
            value colored 
                    = color(annotationsBuilder.string, 
                            Colors.annotations);
            annotationsBuilder.clear();
            annotationsBuilder
                .append("<tt><span style='font-size:85%'>");
            if (decl.deprecated) {
                annotationsBuilder.append("<s>");
            }
            annotationsBuilder.append(colored);
            if (decl.deprecated) {
                annotationsBuilder.append("</s>");
            }
            annotationsBuilder.append("</span></tt>");

            addIconAndText(builder, Icons.annotations, 
                annotationsBuilder.string);
        }
        
        value desc = StringBuilder()
            .append("<tt><span style='font-size:103%'>")
            .append(decl.deprecated then "<s>" else "")
            .append(description(decl, node, pr, cmp, unit))
            .append(decl.deprecated then "</s>" else "")
            .append("</span></tt>");
        addIconAndText(builder, decl, desc.string);
    }

    // see description(Declaration, Node,  Reference, CeylonParseController, Unit)
    shared String description(Declaration decl, Node? node, 
        Reference? r, IdeComponent cmp, Unit unit) {
        
        value pr = r else appliedReference(decl, node);
        
        value description = StringBuilder();
        description
            .append(getDocDescriptionFor(decl, pr, unit, cmp));
        if (is TypeDeclaration decl, decl.\ialias, 
            exists et = decl.extendedType) {
            description
                .append(" => ")
                .append(et.asString());
        }
        if (is FunctionOrValue decl,
            decl is Value && !decl.variable 
                    || decl is Function) {
            description
                .append(getInitialValueDescription(decl, cmp));
        }
        
        value result = highlight(description.string, cmp);
        value liveValue = getLiveValue(decl, unit);
        
        return
            if (exists liveValue)
            then result + liveValue
            else result;
    }

    // see addInheritanceInfo(Declaration, Node, Reference, StringBuilder, Unit)
    Boolean addInheritanceInfo(Declaration decl, Node? node, 
        Reference? pr, StringBuilder builder, Unit unit) {
        
        value div = "<div style='padding-left:20px'>";
        builder.append(div);

        Boolean obj;
        switch (decl)
        case (is TypedDeclaration) {
            if (exists td = decl.typeDeclaration, td.anonymous) {
                obj = true;
                documentInheritance(td, node, pr, builder, unit);
            }
            else {
                obj = false;
            }
        }
        case (is TypeDeclaration) {
            documentInheritance(decl, node, pr, builder, unit);
            obj = false;
        }
        else {
            assert (false);
        }

        documentTypeParameters(decl, node, pr, builder, unit);

        if (builder.endsWith(div)) {
            builder.deleteTerminal(div.size);
        } else {
            builder.append("</div>");
        }  

        return obj;
    }

    // see documentInheritance(TypeDeclaration, Node, Reference, StringBuilder, Unit)
    void documentInheritance(TypeDeclaration decl, Node? node, 
        Reference? r, StringBuilder builder, Unit unit) {
        
        value pr = r else appliedReference(decl, node);
        value type = if (is Type pr) then pr else decl.type;
        
        if (exists cases = type.caseTypes) {
            value casesBuilder = StringBuilder();

            value casesString = { for (c in cases) printer.print(c, unit) };
            
            casesBuilder
                .append(" <tt><span style='font-size:90%'>")
                .append("of&nbsp")
                .append(" | ".join(casesString));
            
            if (exists it = decl.selfType) {
                builder.append(" (self type)");
            }
            casesBuilder.append("</span></tt>");

            addIconAndText(builder, Icons.enumeration, 
                casesBuilder.string);
        }

        if (is Class decl, exists sup = type.extendedType) {
            value text = "<tt><span style='font-size:90%'>extends&nbsp;``printer.print(sup, unit)``</span></tt>";
            addIconAndText(builder, Icons.extendedType, text);
        }

        if (!type.satisfiedTypes.empty) {
            value satisfiesBuilder = StringBuilder();
            
            value typesString = { for (s in type.satisfiedTypes) printer.print(s, unit) };
            
            satisfiesBuilder.append("<tt><span style='font-size:90%'>")
                .append("satisfies&nbsp;")
                .append(" &amp; ".join(typesString))
                .append("</span></tt>");
            
            addIconAndText(builder, Icons.satisfiedTypes, 
                satisfiesBuilder.string);
        }

    }
    
    // see documentTypeParameters(Declaration, Node, Reference, StringBuilder, Unit)
    void documentTypeParameters(Declaration decl, Node? node, 
        Reference? r, StringBuilder builder, Unit unit) {
        
        Reference? pr = r else appliedReference(decl, node);

        for (tp in decl.typeParameters) {
            value bounds = StringBuilder();
            variable value isFirst = true;
            for (st in tp.satisfiedTypes) {
                bounds.append(isFirst then " satisfies " else " &amp; ");
                bounds.append(printer.print(st, decl.unit));
                isFirst = false;
            }
            
            String arg;
            if (exists liveValue = getLiveValue(tp, unit)) {
                arg = liveValue;
            } else if (exists typeArg 
                        = pr?.typeArguments?.get(tp),
                !tp.type.isExactly(typeArg)) {
                arg = "&nbsp;=&nbsp;" 
                        + printer.print(typeArg, unit);
            }
            else {
                arg = "";
            }
            addIconAndText(builder, tp, 
                "given&nbsp;" 
                    + buildLink(tp, tp.name) 
                    + bounds.string 
                    + arg);
        }
    }

    JList<Type> getTypeParameters(Declaration dec) {
        if (dec.parameterized) {
            value typeParameters = dec.typeParameters;
            value list = ArrayList<Type>();
            for (p in typeParameters) {
                list.add(p.type);
            }
            return list;
        } else {
            return Collections.emptyList<Type>();
        }
    }

    Reference? appliedReference(Declaration decl, Node? node) {
        if (is Tree.TypeDeclaration node, is TypeDeclaration decl) {
            return decl.type;
        } else if (is Tree.MemberOrTypeExpression node) {
            return node.target;
        } else if (is Tree.Type node) {
            return node.typeModel;
        } else {
            //a member declaration - unfortunately there is 
            //nothing matching TypeDeclaration.getType() for
            //TypedDeclarations!
            value qt
                    = if (decl.classOrInterfaceMember,
                          is ClassOrInterface ci = decl.container)
                    then ci.type
                    else null;
            
            return decl.appliedReference(qt, getTypeParameters(decl));
        }
    }

    // see addContainerInfo(Declaration dec, Node node, StringBuilder buffer)
    void addContainerInfo(Declaration decl, Reference? pr, 
        Node? node, StringBuilder builder) {
        Unit? unit = node?.unit;
        builder.append("<p>");
        
        if (decl.parameter, is FunctionOrValue decl) {
            if (exists ip = decl.initializerParameter,
                exists pd = ip.declaration) {
                if (exists name = pd.name) {
                    builder.append("Parameter of");
                    if (name.startsWith("anonymous#")) {
                        builder.append(" anonymous function.");
                    } else {
                        appendParameterLink(builder, pd);
                        builder.append(".");
                    }
                } else if (is Constructor pd, 
                           is Class c = pd.container) {
                    builder.append("Parameter of default constructor of");
                    appendParameterLink(builder, c);
                    builder.append(".");
                }
            }
        } else if (is TypeParameter decl) {
            builder.append("Type parameter of");
            appendParameterLink(builder, decl.declaration);
            builder.append(".");
        } else if (decl.classOrInterfaceMember,
                exists qt = getQualifyingType(decl, pr, node)) {
            value desc = switch (decl)
                case (is Constructor)
                    if (exists n = decl.name)
                    then "Constructor of"
                    else "Default constructor of"
                case (is Value)
                    if (decl.static)
                    then "Static attribute of"
                    else "Attribute of"
                case (is Function)
                    if (decl.static)
                    then "Static method of"
                    else "Method of"
                else
                    if (decl.static)
                    then "Static member of"
                    else "Member of";
            
            value typeDesc 
                    = if (qt.declaration.name.startsWith("anonymous#"))
                    then " anonymous class"
                    else "&nbsp;<tt>``printer.print(qt, unit)``</tt>";
            
            builder.append(desc).append(typeDesc).append(".");
        }
        
        if (builder.endsWith("<p>")) {
            builder.deleteTerminal(3);
        } else {
            builder.append("</p>");
        }
    }

    // see appendParameterLink(StringBuilder buffer, Declaration pd)
    void appendParameterLink(StringBuilder builder, Declaration decl) {
        switch (decl)
        case (is Class) {
            builder.append(" class");
        }
        case (is Interface) {
            builder.append(" interface");
        }
        case (is Function) {
            builder.append(decl.classOrInterfaceMember 
                then " method" else " function");
        } case (is Constructor) {
            builder.append(" constructor");
        } else {
        }
        builder.append("&nbsp;");
        if (decl.classOrInterfaceMember, 
            is Referenceable c = decl.container) {
            builder
                .append(buildLink(c, c.nameAsString))
                .append(".");
        }
        builder.append(buildLink(decl, decl.nameAsString));
    }

    Type? getQualifyingType(Declaration dec, Reference? r, 
        Node? node) {
        if (exists r) {
            return r.qualifyingType;
        }
        else if (is Tree.MemberOrTypeExpression node, 
            exists pr = node.target) {
            return pr.qualifyingType;
        }
        else if (is Tree.QualifiedType node) {
            return node.outerType.typeModel;
        }
        else {
            assert (is ClassOrInterface outerClass = dec.container);
            return outerClass.type;
        }
    }

    void addPackageInfo(Declaration decl, StringBuilder builder) {
        if (exists pkg = decl.unit.\ipackage, decl.toplevel) {
            value label
                = if (pkg.nameAsString.empty)
                then "<span>Member of default package.</span>"
                else "<span>Member of package&nbsp;``buildLink(pkg, pkg.qualifiedNameString)``.</span>";
            
            builder.append("<div class='paragraph'>");
            addIconAndText(builder, pkg, label);
            builder.append("</div>");
        }
    }
    
    // see addDoc(Declaration dec, Node node, StringBuilder buffer)
    Boolean addDoc(Declaration dec, Node? node, 
        StringBuilder builder, IdeComponent cmp) {
        value rn
                = let (n = nodes.getReferencedNode(dec))
                if (is Tree.SpecifierStatement n)
                then nodes.getReferencedNode(n.refined) 
                else n;
        if (dec.unit is CeylonUnit) {
            value annotationList 
                    = if (is Tree.Declaration rn) 
                    then rn.annotationList else null;
            value scope = resolveScope(dec);
            appendDeprecatedAnnotationContent(dec, 
                annotationList, builder, scope, cmp);
            value len = builder.size;
            appendDocAnnotationContent(dec, 
                annotationList, builder, scope, cmp);
            Boolean hasDoc = builder.size != len;
            appendThrowAnnotationContent(dec, 
                annotationList, builder, scope, cmp);
            appendSeeAnnotationContent(dec, 
                annotationList, builder, cmp);
            return hasDoc;
        } else {
            appendJavadoc(dec, builder);
            return false;
        }
    }
    
    Scope? resolveScope(Declaration? decl) 
            => if (is Scope decl) 
            then decl 
            else decl?.container;
    
    function findAnnotationModel(Annotated&Referenceable annotated, String name) {
        for (ann in annotated.annotations) {
            if (ann.name == name) {
                return ann;
            }
        }
        else {
            return null;
        }
    }
    
    // see appendDeprecatedAnnotationContent(Tree.AnnotationList, StringBuilder, Scope)
    void appendDeprecatedAnnotationContent(Annotated & Referenceable annotated, 
        Tree.AnnotationList? annotationList, StringBuilder documentation, 
        Scope? linkScope, IdeComponent cmp) {
        
        String? text;
        
        value name = "deprecated";
        if (exists annotationList,
            exists ann = findAnnotation(annotationList, name),
            exists argList = ann.positionalArgumentList,
            !argList.positionalArguments.empty,
            is Tree.ListedArgument a = argList.positionalArguments[0]) {
            text = a.expression.term.text;
        } else if (exists annotation = findAnnotationModel(annotated, name)) {
            text = annotation.positionalArguments[0]?.string;
        } else {
            text = null;
        }
        if (exists text) {
            documentation.append(
                markdown("_(This is a deprecated program element.)_\n\n" + text,
                    cmp, linkScope, annotated.unit));
        }
    }
    
    // see appendDocAnnotationContent(Tree.AnnotationList, StringBuilder, Scope)
    void appendDocAnnotationContent(
        Annotated&Referenceable annotated, 
        Tree.AnnotationList? annotationList, 
        StringBuilder documentation, 
        Scope? linkScope, IdeComponent cmp) {
        value name = "doc";
        
        String? text;
        if (exists annotationList) {
            
            if (exists aa = annotationList.anonymousAnnotation) {
                text = aa.stringLiteral.text;
            } else if (exists ann = findAnnotation(annotationList, name),
                exists argList = ann.positionalArgumentList,
                !argList.positionalArguments.empty,
                exists a = argList.positionalArguments[0],
                is Tree.ListedArgument a) {
                text = a.expression.term.text;
            } else {
                text = null;
            }
        } else if (exists annotation = findAnnotationModel(annotated, name)) {
            text = annotation.positionalArguments[0]?.string;
        } else {
            text = null;
        }
        
        if (exists text) {
            documentation.append(markdown(text, cmp, linkScope, 
                annotated.unit));
        }
    }
    
    AnnotatedMirror? toAnnotatedMirror(Annotated&Referenceable annotated) 
            => switch(annotated)
            case (is LazyClass) annotated.classMirror
            case (is LazyClassAlias) annotated.classMirror
            case (is LazyInterface) annotated.classMirror
            case (is LazyInterfaceAlias) annotated.classMirror
            case (is LazyValue) annotated.classMirror
            case (is LazyTypeAlias) annotated.classMirror
            case (is LazyFunction) annotated.methodMirror
            case (is JavaBeanValue) annotated.mirror
            case (is JavaMethod) annotated.mirror
            else null;
    
    // see appendThrowAnnotationContent(Tree.AnnotationList, StringBuilder, Scope)
    void appendThrowAnnotationContent(
        Annotated&Referenceable annotated, 
        Tree.AnnotationList? annotationList, 
        StringBuilder documentation, 
        Scope? linkScope, IdeComponent cmp) {
        
        Unit? unit = annotated.unit;

        void addThrowsText(Declaration dec, String text) {
            value doc = "throws <tt>``buildLink(dec, dec.name)``</tt>"
                    + markdown(text, cmp, linkScope, unit);
            addIconAndText(documentation, Icons.exceptions, doc);
        }

        if (exists annotationList,
            exists annotation = findAnnotation(annotationList, "throws"),
            exists argList = annotation.positionalArgumentList,
            !argList.positionalArguments.empty) {
            value args = argList.positionalArguments;

            if (is Tree.ListedArgument typeArg = args[0],
                is Tree.ListedArgument? textArg = args[1]) {
                value typeArgTerm = typeArg.expression.term;
                value text = textArg?.expression?.term?.text else "";
                
                if (is Tree.MetaLiteral typeArgTerm,
                    exists dec = typeArgTerm.declaration) {
                    addThrowsText(dec, text);
                }
            }
        } else if (exists annotatedMirror = toAnnotatedMirror(annotated)) {
            if (exists annotationMirror = 
                            annotatedMirror.getAnnotation(
                                LanguageAnnotation.throws.annotationType),
                is JList<out Anything> thrownExceptions
                        = annotationMirror.getValue("value")) {
                for (thrown in thrownExceptions) {
                    if (is AnnotationMirror thrown,
                        exists typeArg = thrown.getValue("type")?.string,
                        exists dec = parseAnnotationType(typeArg, cmp.ceylonProject)) {
                        String textArg = thrown.getValue("when")?.string else "";
                        addThrowsText(dec, textArg);
                    }
                }
            }
        }
    }

    function toRealParent(Declaration? parent)
            => switch(parent)
            case (is Null) null
            case (is LazyValue)
                let (TypeDeclaration? typeDeclaration = parent.typeDeclaration)
                if (equalsWithNulls(typeDeclaration?.qualifiedNameString,
                                    parent.qualifiedNameString))
                then typeDeclaration
                else parent
            else parent;

    Declaration? parseAnnotationType(String encodedDeclaration,
        BaseCeylonProject? project) {
        String withoutVersion;
        if (!exists project) {
            return null;
        }
        if (exists first=encodedDeclaration.first,
            first == ':') {
            // a version exist
            value rest = encodedDeclaration.rest;
            value sentinel = rest.first;
            if (!exists sentinel) {
                return null;
            }
            if (exists versionEnd 
                    = rest.rest.firstOccurrence(sentinel)) {
                withoutVersion = rest.rest.spanFrom(versionEnd+1);
            } else {
                return null;
            }
        } else {
            withoutVersion = encodedDeclaration;
        }
        
        value fromModule
                = withoutVersion.split(':'.equals, true, false);
        value moduleName = fromModule.first;

        Module mod;
        if (exists modules = project.modules) {
            for (m in modules) {
                if (m.nameAsString == moduleName) {
                    mod = m;
                    break;
                }
            } else {
                return null;
            }
        }
        else {
            return null;
        }

        value fromPackage = fromModule.rest;
        value packageName = fromPackage.first;
        if (!exists packageName) {
            return null;
        }
        Package? pkg = mod.getPackage(
            if (exists nameStart = packageName.first,
                nameStart == '.')
            then packageName.rest
            else 
                if (packageName.empty)
                then moduleName
                else "``moduleName``.``packageName``");
        if (!exists pkg) {
            return null;
        }
        
        value fromDeclaration = fromPackage.rest;
        value declaration = fromDeclaration.first;
        if (!exists declaration) {
            return null;
        }
        if (!fromDeclaration.rest.empty) {
            return null; // the syntax cannot be parsed
        }
        value declarationParts = declaration.split('.'.equals)
            .map((s) => s.rest);
        Declaration? topLevelDeclaration
                = pkg.getMember(declarationParts.first, null, false);
        
        variable Declaration? result = topLevelDeclaration;
        for (member in declarationParts.rest) {
            result = toRealParent(result)?.getMember(member, null, false);
        }
        return result;
    }
    
    void appendSeeAnnotationContent(
        Annotated&Referenceable annotated, 
        Tree.AnnotationList? annotationList,
        StringBuilder documentation, IdeComponent cmp) {
        String name = "see";
        value buffer = StringBuilder();
        void addSeeText(Declaration dec) {
            value dn = 
                    if (dec.classOrInterfaceMember,
                        is ClassOrInterface container 
                                = dec.container)
                    then container.name + "." + dec.name
                    else dec.name;
            if (!buffer.empty) {
                buffer.append(", ");
            }
            buffer.append("<tt>")
                    .append(buildLink(dec, dn))
                    .append("</tt>");
        }
        if (exists annotationList,
            exists annotation = findAnnotation(annotationList, name),
            exists argList = annotation.positionalArgumentList) {
            
            for (arg in argList.positionalArguments) {
                if (is Tree.ListedArgument arg,
                    is Tree.MetaLiteral ml = arg.expression.term,
                    exists dec = ml.declaration) {
                    addSeeText(dec);
                }
            }
        } else if (exists annotatedMirror = toAnnotatedMirror(annotated)) {
            if (exists annotationMirror
                    = annotatedMirror.getAnnotation(LanguageAnnotation.see.annotationType),
                is JList<out Anything> seeAnnotations
                        = annotationMirror.getValue("value")) {
                for (see in seeAnnotations) {
                    if (is AnnotationMirror see,
                        is JList<out Anything> programElements
                                = see.getValue("programElements")) {
                        for (pe in programElements) {
                            if (exists pe,
                                exists dec = parseAnnotationType(pe.string, cmp.ceylonProject)) {
                                addSeeText(dec);
                            }
                        }
                    }
                }
            }
        }
        if (!buffer.empty) {
            buffer.prepend("see ");
            buffer.append(".");
            addIconAndText(documentation, Icons.see, buffer.string);
        }
    }

    Tree.Annotation? findAnnotation(Tree.AnnotationList annotations, String name) {
        for (element in annotations.annotations) {
            if (is Tree.BaseMemberExpression primary = element.primary,
                name == primary.identifier.text) {
                return element;
            }
        }
        else {
            return null;
        }
    }
    
    // see addRefinementInfo(Declaration, Node, StringBuilder,  boolean, Unit)
    void addRefinementInfo(Declaration dec, Reference? pr, 
        Node? node, StringBuilder buffer, Boolean hasDoc, 
        Unit unit, IdeComponent cmp) {
        
        if (exists rd = dec.refinedDeclaration, rd != dec) {
            buffer.append("<p>");
            
            assert (is TypeDeclaration superclass = rd.container);            
            value supertype 
                    = getQualifyingType(dec, pr, node)
                        ?.getSupertype(superclass);
            value icon 
                    = rd.formal
                    then Icons.implementation 
                    else Icons.override;
            
            value buf = StringBuilder()
                .append("Refines&nbsp;")
                .append(buildLink(rd, rd.nameAsString))
                .append("&nbsp;declared by&nbsp;<tt>")
                .append(printer.print(supertype, unit))
                .append("</tt>.");
            
            addIconAndText(buffer, icon, buf.string);
            buffer.append("</p>");
            
            if (!hasDoc, 
                is Tree.Declaration decNode 
                        = nodes.getReferencedNode(rd)) {
                appendDocAnnotationContent(dec, 
                    decNode.annotationList, buffer, 
                    resolveScope(rd), cmp);
            }
        }
    }
    
    // see addReturnType(Declaration, StringBuilder, Node, Reference, boolean, Unit)
    void addReturnType(Declaration dec, StringBuilder buffer, 
        Node? node, Reference? r, Boolean obj, Unit unit) {
        
        if (is TypedDeclaration dec, !obj,
            exists pr = r else appliedReference(dec, node),
            exists ret = pr.type) {

            buffer.append("<div class='paragraph'>");

            value buf = StringBuilder()
                .append("Returns&nbsp;<tt>")
                .append(printer.print(ret, unit))
                .append("</tt>.");

            if (dec.hasUncheckedNullType()) {
                buf.append(" (Has unchecked null values.)");
            }
            addIconAndText(buffer, Icons.returns, buf.string);

            buffer.append("</div>");
        }
    }
    
    // see addParameters(CeylonParseController, Declaration, Node, Reference, StringBuilder, Unit)
    void addParameters(IdeComponent cmp, Declaration dec, 
        Node? node, Reference? r, StringBuilder buffer, 
        Unit unit) {
        
        if (is Functional dec,
            exists pr = r else appliedReference(dec, node)) {
            
            for (pl in dec.parameterLists) {
                if (!pl.parameters.empty) {
                    buffer.append("<div class='paragraph'>");
                    
                    for (p in pl.parameters) {
                        if (exists model = p.model) {
                            value param = StringBuilder();
                            param.append("Accepts&nbsp;");
                            appendParameter(param, pr, p, unit);
                            value desc = getInitialValueDescription(model, cmp);
                            param.append("<tt>")
                                .append(highlight(desc, cmp))
                                .append("</tt>")
                                .append(".");
                            
                            if (is Tree.Declaration refNode 
                                    = nodes.getReferencedNode(model)) {
                                appendDocAnnotationContent(model, 
                                    refNode.annotationList,
                                    param, resolveScope(dec), cmp);
                            }
                            
                            addIconAndText(buffer, 
                                Icons.parameters, param.string);
                        }
                    }
                    buffer.append("</div>");
                }
            }
        }
    }
    
    // see appendParameter(StringBuilder result, Reference pr, Parameter p, Unit unit)
    void appendParameter(StringBuilder result, Reference? pr, 
        Parameter p, Unit unit) {
        result.append("<tt>");
        
        if (exists model = p.model) {
            value ppr = pr?.getTypedParameter(p);
            if (p.declaredVoid) {
                result.append(color("void", Colors.keywords));
            } else {
                if (exists t = ppr?.type) {
                    Type? pt = p.sequenced
                        then unit.getSequentialElementType(t) 
                        else t;
                    result.append(printer.print(pt, unit));
                    if (p.sequenced) {
                        result.append(if (p.atLeastOne) then "+" else "*");
                    }
                } else if (model is Function) {
                    result.append(color("function", Colors.keywords));                    
                } else {
                    result.append(color("value", Colors.keywords));
                }
            }
            result.append("&nbsp;");
            result.append("</tt>");
            result.append(buildLink(model, model.nameAsString));
            appendParameters(model, ppr, unit, result);
        } else {
            result.append(p.name);
            result.append("</tt>");
        }
    }
    
    // see appendParameters(Declaration dec, Reference pr, Unit unit, StringBuilder result
    void appendParameters(Declaration dec, Reference? pr, 
        Unit unit, StringBuilder result) {
        
        if (is Functional dec, 
            exists plists = dec.parameterLists) {
            for (params in plists) {
                if (params.parameters.empty) {
                    result.append("()");
                } else {
                    result.append("(");
                    for (p in params.parameters) {
                        appendParameter(result, pr, p, unit);
                        result.append(", ");
                    }
                    result.deleteTerminal(2);
                    result.append(")");
                }
            }
        }
    }
    
    // see addClassMembersInfo(Declaration dec, StringBuilder buffer)
    void addClassMembersInfo(Declaration dec, StringBuilder buffer) {
        if (is ClassOrInterface dec) {
            variable Boolean first = true;
            for (mem in dec.members) {
                if (ModelUtil.isResolvable(mem), mem.shared,
                    !mem.overloaded || mem.abstraction) {
                    if (first) {
                        buffer.append("<p>Members:&nbsp;");
                        first = false;
                    } else {
                        buffer.append(", ");
                    }
                    buffer.append(buildLink(mem, mem.nameAsString));
                }
            }
            if (!first) {
                buffer.append(".</p>");
            }
        }
    }
    
    // see addNothingTypeInfo(StringBuilder buffer)
    void addNothingTypeInfo(StringBuilder buffer) {
        buffer.append("Special bottom type defined by the language.
                       <code>Nothing</code> is assignable to all types, but has no value.
                       A function or value of type <code>Nothing</code> either throws
                       an exception, or never returns.");
    }
    
    // see addUnitInfo(Declaration dec, StringBuilder buffer)
    void addUnitInfo(Declaration decl, StringBuilder builder) {
        // <p> was replaced with <div> because <p> can't contain <div>s
        builder.append("<div class='paragraph'>");
        value unit = decl.unit;
        value unitName
                = if (is CeylonUnit unit,
                      exists name = unit.ceylonFileName)
                then name
                else unit.filename;
        value text = "<span>Declared in&nbsp;``buildLink(decl, unitName, "dec")``.</span>";
        addIconAndText(builder, Icons.units, text);
        addPackageModuleInfo(decl.unit.\ipackage, builder);
        builder.append("</div>");
    }

    // see addPackageModuleInfo(Package pack, StringBuilder buffer)
    void addPackageModuleInfo(Package pack, StringBuilder buffer) {
        value mod = pack.\imodule;
        value label = 
            if (mod.nameAsString.empty || mod.nameAsString == "default")
            then "<span>Belongs to default module.</span>"
            else "<span>Belongs to&nbsp;``buildLink(mod, mod.nameAsString)``"
               + "&nbsp;<tt>``color("\"``mod.version``\"", Colors.strings)``</tt>.</span>";
        addIconAndText(buffer, mod, label);
    }
}
