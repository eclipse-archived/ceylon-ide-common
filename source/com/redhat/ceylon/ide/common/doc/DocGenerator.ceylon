import ceylon.interop.java {
    javaString,
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.util {
    nodes,
    escaping
}
import com.redhat.ceylon.model.cmr {
    JDKUtils
}
import com.redhat.ceylon.model.typechecker.model {
    Referenceable,
    Declaration,
    Package,
    Module,
    Scope,
    Annotated,
    Unit,
    FunctionOrValue,
    TypeDeclaration,
    Value,
    TypedDeclaration,
    Class,
    Interface,
    TypeAlias,
    ModelUtil,
    Reference,
    Type,
    UnknownType,
    Functional,
    Generic,
    SiteVariance,
    Parameter,
    TypedReference,
    ClassOrInterface,
    TypeParameter,
    Constructor,
    Function,
    NothingType
}
import com.redhat.ceylon.model.typechecker.util {
    TypePrinter
}

import java.lang {
    JCharacter=Character {
        UnicodeScript,
        UnicodeBlock
    }
}
import java.util {
    Collections
}

shared abstract class Icon() of annotations {}
shared object annotations extends Icon() {}

shared abstract class DocGenerator<IdeComponent>() {
    
    shared formal String buildLink(Referenceable model, String text, String protocol = "doc");
    shared formal TypePrinter printer;
    shared formal String color(Object? what, Colors how);
    shared formal String markdown(String text, IdeComponent cmp, Scope? linkScope = null, Unit? unit = null);
    shared formal void addIconAndText(StringBuilder builder, Icons|Referenceable icon, String text);
    shared formal String getDefaultValueDescription(Parameter p, IdeComponent cmp);
    shared formal String getInitialValueDescription(Declaration d, IdeComponent cmp);
    shared formal String highlight(String text, IdeComponent cmp);
    shared formal void appendJavadoc(Declaration model, StringBuilder buffer);
    shared formal Boolean showMembers;
    shared formal void appendPageProlog(StringBuilder builder);
    shared formal void appendPageEpilog(StringBuilder builder);
    shared formal String getUnitName(Unit u);
    shared formal String? getLiveValue(Declaration dec, Unit unit);
    
    "Get the Node referenced by the given model, searching
     in all relevant compilation units."
    shared formal Node? getReferencedNode(Declaration dec);
    
    // see getHoverText(CeylonEditor editor, IRegion hoverRegion)
    shared String? getDocumentation(Tree.CompilationUnit rootNode, Integer offset, IdeComponent cmp) {
        value node = getHoverNode(rootNode, offset);
        variable String? doc = null;
        
        if (exists node) {
            if (is Tree.LocalModifier node) {
                doc = getInferredTypeText(node, cmp);
            } else if (is Tree.Literal node) {
                doc = getTermTypeText(node);
            } else {
                Referenceable? model = nodes.getReferencedDeclaration(node);
                
                if (exists model) {
                    doc = getDocumentationText(model, node, rootNode, cmp);
                }
            }
        }
        
        return doc;
    }
    
    // see SourceInfoHover.getHoverNode(IRegion hoverRegion, CeylonParseController parseController)
    Node? getHoverNode(Tree.CompilationUnit rootNode, Integer offset) {
        return nodes.findNode(rootNode, offset);
    }
    
    // see getInferredTypeHoverText(Node node, IProject project)
    String? getInferredTypeText(Tree.LocalModifier node, IdeComponent cmp) {
        if (exists model = node.typeModel) {
            value builder = StringBuilder();
            appendPageProlog(builder);
            
            value text = "Inferred type: <tt>``printer.print(model, node.unit)``</tt>";
            addIconAndText(builder, Icons.types, text);
            
            appendPageEpilog(builder);
            return builder.string;
        }
        
        return null;
    }
    
    //see getTermTypeHoverText(Node node, String selectedText, IDocument doc, IProject project)
    String? getTermTypeText(Tree.Term term) {
        if (exists model = term.typeModel) {
            value builder = StringBuilder();
            
            builder.append(if (is Tree.Literal term) then "Literal of type" else "Expression of type");
            builder.append(" ").append(printer.print(model, term.unit)).append("<br/>\n<br/>\n");
            
            if (is Tree.StringLiteral term) {
                value text = if (term.text.size < 250) then escape(term.text) else escape(term.text.spanTo(250)) + "...";
                builder.append(color("\"``text``\"", Colors.strings));
                
                // TODO display info for selected char? 
            } else if (is Tree.CharLiteral term, term.text.size > 2) {
                appendCharacterInfo(builder, term.text.span(1, 1));
            } else if (is Tree.NaturalLiteral term) {
                value text = term.text.replace("_", "");
                value int = switch (text.first)
                    case ('#') parseInteger(text.spanFrom(1), 16)
                    case ('$') parseInteger(text.spanFrom(1), 2)
                    else parseInteger(text);
                
                builder.append(color(int, Colors.numbers));
            } else if (is Tree.FloatLiteral term) {
                builder.append(color(parseFloat(term.text.replace("_", "")), Colors.numbers));
            }
            
            return builder.string;
        }
        
        return null;
    }
    
    String escape(String content) => content.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;");
    
    void appendCharacterInfo(StringBuilder builder, String string) {
        builder.append(color(escape("'``string``'"), Colors.strings)).append("<br/>\n");
        value codepoint = JCharacter.codePointAt(javaString(string), 0);
        builder.append("Unicode name: ").append(JCharacter.getName(codepoint)).append("<br/>\n");
        builder.append("Codepoint: <code>U+").append(formatInteger(codepoint, 16).uppercased.padLeading(4, '0')).append("</code><br/>\n");
        // TODO general category name
        builder.append("Script: <code>").append(UnicodeScript.\iof(codepoint).name()).append("</code><br/>\n");
        builder.append("Block: <code>").append(UnicodeBlock.\iof(codepoint).string).append("</code>");
    }
    
    // see getDocumentationHoverText(Referenceable model, CeylonEditor editor, Node node)
    shared String? getDocumentationText(Referenceable model, Node node, Tree.CompilationUnit rootNode, IdeComponent cmp) {
        if (is Declaration model) {
            return getDeclarationDoc(model, node, rootNode, cmp, null);
        } else if (is Package model) {
            return getPackageDoc(model, node, cmp);
        } else if (is Module model) {
            return getModuleDoc(model, node, cmp);
        }
        
        return null;
    }

    // see getDocumentationFor(CeylonParseController controller, Declaration dec, Node node, Reference pr)
    String getDeclarationDoc(Declaration model, Node node, Tree.CompilationUnit rootNode, IdeComponent cmp, Reference? pr) {
        variable value decl = model;
        if (is FunctionOrValue model) {
            TypeDeclaration? typeDecl = model.typeDeclaration;
            
            if (exists typeDecl, typeDecl.anonymous, !model.type.typeConstructor) {
                decl = typeDecl;
            }
        }
        
        value builder = StringBuilder();
        appendPageProlog(builder);
        value unit = rootNode.unit;
        
        addMainDescription(builder, decl, node, pr, cmp, unit);
        value isObj = addInheritanceInfo(decl, node, pr, builder, unit);
        if (!is NothingType d = decl) {
            addPackageInfo(decl, builder);
        }
        addContainerInfo(decl, node, builder); //TODO: use the pr to get the qualifying type??
        value hasDoc = addDoc(decl, node, builder, cmp);
        addRefinementInfo(decl, node, builder, hasDoc, unit, cmp); //TODO: use the pr to get the qualifying type??
        addReturnType(decl, builder, node, pr, isObj, unit);
        addParameters(cmp, decl, node, pr, builder, unit);
        if (showMembers) {
            addClassMembersInfo(decl, builder);
        }
        if (is NothingType d = decl) {
            addNothingTypeInfo(builder);
        } else {
            addUnitInfo(decl, builder);
        }
        
        appendPageEpilog(builder);
        
        return builder.string;
    }

    String getPackageDoc(Package pack, Node node, IdeComponent cmp) {
        value builder = StringBuilder();
        
        if (pack.shared) {
            builder.append(color("shared ", Colors.annotations));
        }
        
        builder.append(color("package ", Colors.keywords)).append(pack.nameAsString).append("<br/>\n");
        
        appendDoc(pack, builder, pack, cmp);
        // TODO see annotation
        
        value mod = pack.\imodule;
        if (mod.java) {
            builder.append("<p>This package is implemented in Java.</p>\n");
        }
        if (JDKUtils.isJDKModule(mod.nameAsString)) {
            builder.append("<p>This package forms part of the Java SDK.</p>\n");             
        }
        
        // TODO? members
        
        builder.append("<br/>\n");
        variable String inModule;
        
        if (mod.nameAsString.empty || mod.nameAsString.equals("default")) {
            inModule = "in default module\n";             
        } else {
            value version = "\"``mod.version``\"";
            inModule = "in module " + buildLink(mod, mod.nameAsString) + " " + color(version, Colors.strings);
        }
        addIconAndText(builder, Icons.modules, inModule);
        
        return builder.string;
    }
    
    String? getModuleDoc(Module mod, Node node, IdeComponent cmp) {
        value builder = StringBuilder();
        
        builder.append(color("module ", Colors.keywords))
                .append(mod.nameAsString)
                .append(color(" \"``mod.version``\"", Colors.strings))
                .append("\n");
        
        if (mod.java) {
            builder.append("<p>This module is implemented in Java.</p>");
        }
        if (mod.default) {
            builder.append("<p>The default module for packages which do not belong to explicit module.</p>");
        }
        if (JDKUtils.isJDKModule(mod.nameAsString)) {
            builder.append("<p>This module forms part of the Java SDK.</p>");            
        }
        
        appendDoc(mod, builder, mod.getPackage(mod.nameAsString), cmp);
        // TODO? members
        
        return builder.string;
    }

    void appendDoc(Annotated&Referenceable decl, StringBuilder builder, Scope? scope, IdeComponent cmp) {
        value doc = CeylonIterable(decl.annotations).find((ann) => ann.name.equals("doc") || ann.name.empty);
        
        if (exists doc, !doc.positionalArguments.empty) {
            value string = markdown(doc.positionalArguments.get(0).string, cmp, scope, decl.unit);
            builder.append(string);
        }
    }

    void addMainDescription(StringBuilder builder, Declaration decl, Node node, Reference? pr, IdeComponent cmp, Unit unit) {
        value annotationsBuilder = StringBuilder();
        if (decl.shared) { annotationsBuilder.append("shared "); }
        if (decl.actual) { annotationsBuilder.append("actual "); }
        if (decl.default) { annotationsBuilder.append("default "); }
        if (decl.formal) { annotationsBuilder.append("formal "); }
        if (is Value decl, decl.late) { annotationsBuilder.append("late "); }
        if (is TypedDeclaration decl, decl.variable) { annotationsBuilder.append("variable "); }
        if (decl.native) { annotationsBuilder.append("native"); }
        if (exists backend = decl.nativeBackend, !backend.empty) {
            annotationsBuilder.append("(").append(color("\"" + backend + "\"", Colors.strings)).append(")");
        }
        if (decl.native) { annotationsBuilder.append(" "); }
        if (is TypeDeclaration decl) {
            if (decl.sealed) { annotationsBuilder.append("sealed "); }
            if (decl.final) { annotationsBuilder.append("final "); }
            if (is Class decl, decl.abstract) { annotationsBuilder.append("abstract "); }
        }
        if (decl.annotation) { annotationsBuilder.append("annotation "); }
        
        if (annotationsBuilder.size > 0) {
            addIconAndText(builder, Icons.annotations, color(annotationsBuilder.string, Colors.annotations) + "\n");
        }
        
        addIconAndText(builder, decl, description(decl, node, pr, cmp, unit));
    }

    // see description(Declaration dec, Node node,  Reference pr, CeylonParseController cpc, Unit unit)
    shared String description(Declaration decl, Node node, Reference? _pr, IdeComponent cmp, Unit unit) {
        value pr = _pr else appliedReference(decl, node);
        value doc = getDocDescriptionFor(decl, pr, unit, cmp);
        value description = StringBuilder();
        
        description.append(doc);
        
        if (is TypeDeclaration decl, decl.\ialias, exists et = decl.extendedType) {
            description.append(" => ").append(et.asString());
        }
        if (is FunctionOrValue decl, (decl is Value && !decl.variable) || decl is Function) {
            description.append(getInitialValueDescription(decl, cmp));
        }
        
        value result = highlight(description.string, cmp);
        value liveValue = getLiveValue(decl, unit);
        
        return if (exists liveValue) then result + liveValue else result;
    }
    
    // see CodeCompletions.getDocDescriptionFor
    String getDocDescriptionFor(Declaration decl, Reference? pr, Unit unit, IdeComponent cmp) {
        StringBuilder result = StringBuilder();
        
        appendDeclarationHeader(decl, pr, unit, result, true);
        appendTypeParameters(decl, pr, unit, result, true);
        appendParametersDescription(decl, pr, unit, result, true, cmp);
        
        return result.string;
    }
    
    // see CodeCompletions.appendDeclarationHeader
    void appendDeclarationHeader(Declaration decl, Reference? pr, Unit unit, StringBuilder builder, Boolean descriptionOnly) {
        if (is TypeAlias decl, decl.anonymous) {
            return;
        }
        
        if (ModelUtil.isConstructor(decl)) {
            builder.append("new");
        } else {
            switch (decl)
            case (is Class) {
                builder.append(if (decl.anonymous) then "object" else "class");
            }
            case (is Interface) {
                builder.append("interface");
            }
            case (is TypeAlias) {
                builder.append("alias");
            }
            case (is TypedDeclaration) {
                value sequenced = if (is FunctionOrValue fov = decl, decl.parameter, fov.initializerParameter.sequenced) 
                    then true else false;
                
                variable Type? type = if (exists pr) then pr.type else decl.type;
                
                if (sequenced, exists t = type) {
                    if (!t.typeArgumentList.empty) {
                        type = t.typeArgumentList.get(0);
                    }
                }
                
                if (!exists t = type) {
                    type = UnknownType(unit).type;
                }
                
                assert(exists t = type);
                
                String typeName = if (descriptionOnly) then t.asString(unit) else t.asSourceCodeString(unit);
                
                if (decl.dynamicallyTyped) {
                    builder.append("dynamic");
                } else if (is Value decl, t.declaration.anonymous, !t.typeConstructor) {
                    builder.append("object");
                } else if (is Functional decl) {
                    builder.append(if (decl.declaredVoid) then "void" else typeName);
                } else {
                    builder.append(typeName);
                }
                
                if (sequenced) {
                    builder.append(if (is FunctionOrValue decl, decl.initializerParameter.atLeastOne) then "+" else "*");
                }
            }
            else {
            }
        }
        
        builder.append(" ");
        
        if (exists name = decl.name) {
            builder.append(if (descriptionOnly) then name else escaping.escapeName(decl));
        }
    }

    // see CodeCompletions.appendTypeParameters
    void appendTypeParameters(Declaration d, Reference? pr, Unit unit, StringBuilder result, Boolean variances) {
        if (is Generic d) {
            value types = d.typeParameters;
            
            if (!types.empty) {
                result.append("&lt;");

                CeylonIterable(types).fold(true)((isFirst, tp) {
                    if (!isFirst) { result.append(", "); }

                    value arg = if (exists pr) then pr.typeArguments.get(tp) else null;
                    
                    if (!exists arg) {
                        if (variances) {
                            if (tp.covariant) {
                                result.append("out ");
                            } else if (tp.contravariant) {
                                result.append("in ");
                            }
                        }
                        result.append(tp.name);
                    } else {
                        if (is Type pr, variances) {
                            SiteVariance? variance = pr.varianceOverrides.get(tp);
                            
                            if (!exists variance) {
                                if (tp.covariant) {
                                    result.append("out ");
                                } else if (tp.contravariant) {
                                    result.append("in ");
                                }
                            } else if (variance == SiteVariance.\iOUT) {
                                result.append("out ");
                            } else if (variance == SiteVariance.\iIN) {
                                result.append("in ");
                            }
                        }
                        result.append(tp.name);
                    }
                    
                    return false;
                });

                result.append("&gt;");
            }
        }
    }

    // see CodeCompletions.appendParametersDescription
    void appendParametersDescription(Declaration decl, Reference? pr, Unit unit, StringBuilder result, Boolean descriptionOnly, IdeComponent cmp) {
        if (is Functional decl, exists plists = decl.parameterLists) {
            CeylonIterable(plists).each(void (params) {
                if (params.parameters.empty) {
                    result.append("()");
                } else {
                    result.append("(");
                    
                    CeylonIterable(params.parameters).fold(true)((isFirst, param) {
                        if (!isFirst) { result.append(", "); }
                        
                        appendParameterDescription(param, pr, unit, result, descriptionOnly, cmp);
                        result.append(getDefaultValueDescription(param, cmp));
                        
                        return false;
                    });

                    result.append(")");
                }
            });
        }
    }

    void appendParameterDescription(Parameter param, Reference? pr, Unit unit, StringBuilder result, Boolean descriptionOnly, IdeComponent cmp) {
        if (exists model = param.model) {
            TypedReference? ppr = pr?.getTypedParameter(param) else null;
            appendDeclarationHeader(model, ppr, unit, result, descriptionOnly);
            appendParametersDescription(model, ppr, unit, result, descriptionOnly, cmp);
        } else {
            result.append(param.name);
        }
    }
    
    // see addInheritanceInfo(Declaration dec, Node node, Reference pr, StringBuilder buffer, Unit unit)
    Boolean addInheritanceInfo(Declaration decl, Node node, Reference? pr, StringBuilder builder, Unit unit) {
        builder.append("<p><div style='padding-left:20px'>");
        variable Boolean obj = false;
        
        if (is TypedDeclaration decl) {
            if (exists td = decl.typeDeclaration, td.anonymous) {
                obj = true;
                documentInheritance(td, node, pr, builder, unit);
            }
        } else if (is TypeDeclaration decl) {
            documentInheritance(decl, node, pr, builder, unit);
        }
        documentTypeParameters(decl, node, pr, builder, unit);
        builder.append("</div></p>");
        return obj;
    }

    // see documentInheritance(TypeDeclaration dec, Node node, Reference pr, StringBuilder buffer, Unit unit)
    void documentInheritance(TypeDeclaration decl, Node node, Reference? _pr, StringBuilder builder, Unit unit) {
        value pr = _pr else appliedReference(decl, node);
        value type = if (is Type pr) then pr else decl.type;
        
        if (exists cases = type.caseTypes) {
            value casesBuilder = StringBuilder();

            casesBuilder.append("of&nbsp")
                .append(" | ".join(CeylonIterable(cases).map((c) => printer.print(c, unit))));
            
            // FIXME compilation error
            // see https://github.com/ceylon/ceylon-compiler/issues/2222
            //if (exists it = decl.selfType) {
            //    builder.append(" (self type)");
            //}

            addIconAndText(builder, Icons.enumeration, casesBuilder.string);
        }

        if (is Class decl, exists sup = decl.extendedType) {
            addIconAndText(builder, Icons.extendedType, "extends&nbsp;" + printer.print(sup, unit));
        }

        if (!decl.satisfiedTypes.empty) {
            value satisfiesBuilder = StringBuilder();
            
            satisfiesBuilder.append("satisfies&nbsp;")
                .append(" &amp; ".join(CeylonIterable(decl.satisfiedTypes).map((s) => printer.print(s, unit))));
            
            addIconAndText(builder, Icons.satisfiedTypes, satisfiesBuilder.string);
        }

    }
    
    // see documentTypeParameters(Declaration dec, Node node, Reference pr, StringBuilder buffer, Unit unit)
    void documentTypeParameters(Declaration decl, Node node, Reference? _pr, StringBuilder builder, Unit unit) {
        Reference? pr = _pr else appliedReference(decl, node);
        value typeParameters = if (is Generic decl) then decl.typeParameters else Collections.emptyList<TypeParameter>();

        for (tp in CeylonIterable(typeParameters)) {
            value bounds = StringBuilder();
            CeylonIterable(tp.satisfiedTypes).fold(true)((isFirst, st) {
                bounds.append(if (isFirst) then " satisfies " else " &amp; ");
                bounds.append(printer.print(st, decl.unit));
                return false;
            });
            
            variable String arg = "";
            value liveValue = getLiveValue(tp, unit);
            
            if (exists liveValue) {
                arg = liveValue;
            } else if (exists typeArg = pr?.typeArguments?.get(tp), !tp.type.isExactly(typeArg)) {
                 arg = "&nbsp;=&nbsp;" + printer.print(typeArg, unit);
            }
            
            value tpLink = buildLink(tp, tp.name);
            addIconAndText(builder, tp, "given&nbsp;" + tpLink + bounds.string + arg);
        }
    }

    Reference? appliedReference(Declaration decl, Node node) {
        if (is TypeDeclaration decl) {
            return decl.type;
        } else if (is Tree.MemberOrTypeExpression node) {
            return node.target;
        } else if (is Tree.Type node) {
            return node.typeModel;
        } else {
            variable Type? qt = null;
            
            if (decl.classOrInterfaceMember, is ClassOrInterface ci = decl.container) {
                qt = ci.type;
            }
            
            return decl.appliedReference(qt, null);
        }
    }

    // see addContainerInfo(Declaration dec, Node node, StringBuilder buffer)
    void addContainerInfo(Declaration decl, Node? node, StringBuilder builder) {
        Unit? unit = node?.unit;
        builder.append("<p>");
        
        if (decl.parameter, is FunctionOrValue decl) {
            value pd = decl.initializerParameter.declaration;
            
            if (!exists n = pd.name) {
                if (is Constructor pd) {
                    builder.append("Parameter of default constructor of");
                    if (is Declaration c = pd.container) {
                        appendParameterLink(builder, c);
                        builder.append(".");
                    }
                }
            } else if (pd.name.startsWith("anonymous#")) {
                builder.append("Parameter of anonymous function.");
            } else {
                builder.append("Parameter of");
                appendParameterLink(builder, pd);
                builder.append(".");
            }
        } else if (decl.classOrInterfaceMember, is ClassOrInterface outerClass = decl.container,
                exists qt = getQualifyingType(node, outerClass)) {
            value desc = switch (decl)
                case (is Constructor)
                    if (exists n = decl.name) then "Constructor of" else "Default constructor of"
                case (is Value)
                    if (decl.staticallyImportable) then "Static attribute of" else "Attribute of"
                case (is Function)
                    if (decl.staticallyImportable) then "Static method of" else "Method of"
                else
                    if (decl.staticallyImportable) then "Static member of" else "Member of"
                ;
            
            value typeDesc = if (qt.declaration.name.startsWith("anonymous#"))
                then " anonymous class"
                else "&nbsp;<tt>" + printer.print(qt, unit) + "</tt>";
            
            builder.append(desc).append(typeDesc).append(".");
        }
        
        builder.append("</p>");
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
            builder.append(if (decl.classOrInterfaceMember) then " method" else " function");
        } case (is Constructor) {
            builder.append(" constructor");
        } else {
        }
        builder.append("&nbsp;");
        if (decl.classOrInterfaceMember, is Referenceable c = decl.container) {
            builder.append(buildLink(c, c.nameAsString)).append(".");
        }
        buildLink(decl, decl.nameAsString);
    }

    Type? getQualifyingType(Node? node, ClassOrInterface? outerClass) {
        if (!exists outerClass) {
            return null;
        }
        
        if (is Tree.MemberOrTypeExpression node, exists pr = node.target) {
            return pr.qualifyingType;
        }
        if (is Tree.QualifiedType node) {
            return node.outerType.typeModel;
        }
        
        assert(exists outerClass);
        return outerClass.type;
    }

    void addPackageInfo(Declaration decl, StringBuilder builder) {
        Package? pkg = (decl of Referenceable).unit.\ipackage;
        
        if (exists pkg, decl.toplevel) {
            value label = if (pkg.nameAsString.empty)
                then "<span>Member of default package.</span>"
                else "<span>Member of package ``buildLink(pkg, pkg.qualifiedNameString)``.</span>";
            
            addIconAndText(builder, pkg, label);
        }
    }
    
    // see addDoc(Declaration dec, Node node, StringBuilder buffer)
    Boolean addDoc(Declaration dec, Node node, StringBuilder builder, IdeComponent cmp) {
        variable Boolean hasDoc = false;
        Node? rn = getReferencedNode(dec);
        
        if (is Tree.Declaration rn) {
            Tree.AnnotationList? annotationList = rn.annotationList;
            value scope = resolveScope(dec);
            appendDeprecatedAnnotationContent(annotationList, builder, scope, cmp);
            value len = builder.size;
            appendDocAnnotationContent(annotationList, builder, scope, cmp);
            hasDoc = builder.size != len;
            appendThrowAnnotationContent(annotationList, builder, scope, cmp);
            appendSeeAnnotationContent(annotationList, builder, cmp);
        } else {
            appendJavadoc(dec, builder);
        }
        return hasDoc;
    }
    
    Scope? resolveScope(Declaration? decl) {
        if (is Scope decl) {
            return decl;
        } else {
            return decl?.container;
        }
    }
    
    // see appendDeprecatedAnnotationContent(Tree.AnnotationList annotationList, StringBuilder documentation, Scope linkScope)
    void appendDeprecatedAnnotationContent(Tree.AnnotationList? annotationList, StringBuilder documentation, Scope? linkScope, IdeComponent cmp) {
        if (exists annotationList, exists ann = findAnnotation(annotationList, "deprecated"),
             exists argList = ann.positionalArgumentList, !argList.positionalArguments.empty,
             is Tree.ListedArgument a = argList.positionalArguments.get(0),
             exists text = a.expression.term.text) {
            
            documentation.append(markdown("_(This is a deprecated program element.)_\n\n" + text, cmp, linkScope, annotationList.unit));
        }
    }
    
    // see appendDocAnnotationContent(Tree.AnnotationList annotationList, StringBuilder documentation, Scope linkScope)
    void appendDocAnnotationContent(Tree.AnnotationList? annotationList, StringBuilder documentation, Scope? linkScope, IdeComponent cmp) {
        if (exists annotationList) {
            value unit = annotationList.unit;
            
            if (exists aa = annotationList.anonymousAnnotation) {
                documentation.append(markdown(aa.stringLiteral.text, cmp, linkScope, unit));
            }

            if (exists ann = findAnnotation(annotationList, "doc"),
                exists argList = ann.positionalArgumentList,
                !argList.positionalArguments.empty,
                exists a = argList.positionalArguments.get(0),
                is Tree.ListedArgument a,
                exists text = a.expression.term.text) {
                
                documentation.append(markdown(text, cmp, linkScope, unit));
            }
        }
    }
    
    // see appendThrowAnnotationContent(Tree.AnnotationList annotationList, StringBuilder documentation, Scope linkScope)
    void appendThrowAnnotationContent(Tree.AnnotationList? annotationList, StringBuilder documentation, Scope? linkScope, IdeComponent cmp) {
        if (exists annotationList, exists annotation = findAnnotation(annotationList, "throws"),
            exists argList = annotation.positionalArgumentList,
            !argList.positionalArguments.empty) {
            value args = argList.positionalArguments;
            value typeArg = args.get(0);
            value textArg = if (args.size() > 1) then args.get(1) else null;
            
            if (is Tree.ListedArgument typeArg, is Tree.ListedArgument? textArg) {
                value typeArgTerm = typeArg.expression.term;
                value text = textArg?.expression?.term?.text else "";
                
                if (is Tree.MetaLiteral typeArgTerm, exists dec = typeArgTerm.declaration) {
                    value dn = dec.name;
                    
                    // TODO intersection is empty: if (is Tree.QualifiedMemberOrTypeExpression typeArgTerm) {
                    
                    value doc = "throws <tt>" + buildLink(dec, dn) + "</tt>" + markdown(text, cmp, linkScope, annotationList.unit);
                    addIconAndText(documentation, Icons.exceptions, doc);
                }
            }
        }
    }
    
    void appendSeeAnnotationContent(Tree.AnnotationList? annotationList, StringBuilder documentation, IdeComponent cmp) {
        if (exists annotationList, exists annotation = findAnnotation(annotationList, "see"),
            exists argList = annotation.positionalArgumentList) {
            value sb = StringBuilder();
            
            for (arg in CeylonIterable(argList.positionalArguments)) {
                if (is Tree.ListedArgument arg, is Tree.MetaLiteral ml = arg.expression.term,
                    exists dec = ml.declaration) {
                    
                    value dn = if (dec.classOrInterfaceMember, is ClassOrInterface container = dec.container)
                        then container.name + "." + dec.name
                        else dec.name;
                    
                    if (sb.size > 0) {
                        sb.append(", ");
                    }
                    sb.append("<tt>").append(buildLink(dec, dn)).append("</tt>");
                }
            }
            
            if (sb.size > 0) {
                sb.prepend("see");
                sb.append(".");
                addIconAndText(documentation, Icons.see, sb.string);
            }
        }
    }

    Tree.Annotation? findAnnotation(Tree.AnnotationList annotations, String name) {
        return CeylonIterable(annotations.annotations).find((element) {
            if (is Tree.BaseMemberExpression primary = element.primary) {
                return name.equals(primary.identifier.text); 
            }
            return false;
        });
    }
    
    // see addRefinementInfo(Declaration dec, Node node, StringBuilder buffer,  boolean hasDoc, Unit unit)
    void addRefinementInfo(Declaration dec, Node node, StringBuilder buffer, Boolean hasDoc, Unit unit, IdeComponent cmp) {
        if (exists rd = dec.refinedDeclaration, rd != dec) {
            buffer.append("<p>");
            
            assert(is TypeDeclaration superclass = rd.container);
            assert(is ClassOrInterface outerCls = dec.container);
            
            value sup = getQualifyingType(node, outerCls)?.getSupertype(superclass);
            value icon = if (rd.formal) then Icons.implementation else Icons.override;
            value text = "Refines&nbsp;" + buildLink(rd, rd.nameAsString) + "&nbsp;declared by&nbsp;<tt>"
                + printer.print(sup, unit) + "</tt>.";
            
            addIconAndText(buffer, icon, text);
            buffer.append("</p>");
            
            if (!hasDoc, is Tree.Declaration decNode = nodes.getReferencedNode(rd)) {
                appendDocAnnotationContent(decNode.annotationList, buffer, resolveScope(rd), cmp);
            }
        }
    }
    
    // see addReturnType(Declaration dec, StringBuilder buffer, Node node, Reference pr, boolean obj, Unit unit)
    void addReturnType(Declaration dec, StringBuilder buffer, Node node, Reference? _pr, Boolean obj, Unit unit) {
        if (is TypedDeclaration dec, !obj) {
            value pr = _pr else appliedReference(dec, node);
            
            if (exists pr, exists ret = pr.type) {
                buffer.append("<p>");
                
                value buf = StringBuilder();
                buf.append("Returns&nbsp;<tt>");
                buf.append(printer.print(ret, unit));
                buf.append("</tt>.");
                
                addIconAndText(buffer, Icons.returns, buf.string);
                
                buffer.append("</p>");
            }
        }
    }
    
    // see addParameters(CeylonParseController cpc, Declaration dec, Node node, Reference pr, StringBuilder buffer, Unit unit)
    void addParameters(IdeComponent cmp, Declaration dec, Node node, Reference? _pr, StringBuilder buffer, Unit unit) {
        if (is Functional dec) {
            value pr = _pr else appliedReference(dec, node);
            
            if (exists pr) {
                for (pl in CeylonIterable(dec.parameterLists)) {
                    if (!pl.parameters.empty) {
                        buffer.append("<p>");
                        
                        for (p in CeylonIterable(pl.parameters)) {
                            if (exists model = p.model) {
                                value param = StringBuilder();
                                param.append("Accepts&nbsp;");
                                appendParameter(param, pr, p, unit);
                                param.append("<tt>")
                                    .append(highlight(getInitialValueDescription(model, cmp), cmp))
                                    .append("</tt>")
                                    .append(".");
                                
                                if (is Tree.Declaration refNode = getReferencedNode(model)) {
                                    appendDocAnnotationContent(refNode.annotationList, param, resolveScope(dec), cmp);
                                }
                                
                                addIconAndText(buffer, Icons.parameters, param.string);
                            }
                        }
                        buffer.append("</p>");
                    }
                }
            }
        }
    }
    
    // see appendParameter(StringBuilder result, Reference pr, Parameter p, Unit unit)
    void appendParameter(StringBuilder result, Reference? pr, Parameter p, Unit unit) {
        result.append("<tt>");
        
        if (exists model = p.model) {
            value ppr = pr?.getTypedParameter(p);
            
            if (p.declaredVoid) {
                result.append(color("void", Colors.keywords));
            } else {
                if (exists ppr) {
                    variable Type? pt = ppr.type;
                    
                    if (exists type = pt, p.sequenced) {
                        pt = p.declaration.unit.getSequentialElementType(type);
                    }
                    result.append(printer.print(pt, unit));
                    if (p.sequenced) {
                        result.append(if (p.atLeastOne) then "+" else "*");
                    }
                } else if (is Function m = p.model) {
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
    void appendParameters(Declaration dec, Reference? pr, Unit unit, StringBuilder result) {
        if (is Functional dec, exists plists = dec.parameterLists) {
            for (params in CeylonIterable(plists)) {
                if (params.parameters.empty) {
                    result.append("()");
                } else {
                    result.append("(");
                    for (p in CeylonIterable(params.parameters)) {
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
            
            for (mem in CeylonIterable(dec.members)) {
                if (ModelUtil.isResolvable(mem), mem.shared, !mem.overloaded || mem.abstraction) {
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
        builder.append("<p>");
        value text = "<span>Declared in&nbsp;<tt>``buildLink(decl, getUnitName(decl.unit), "dec")``</tt>.</span>";

        addIconAndText(builder, Icons.units, text);
        addPackageModuleInfo(decl.unit.\ipackage, builder);
        
        builder.append("</p>");
    }

    // see addPackageModuleInfo(Package pack, StringBuilder buffer)
    void addPackageModuleInfo(Package pack, StringBuilder buffer) {
        value mod = pack.\imodule;
        value label = if (mod.nameAsString.empty || mod.nameAsString.equals("default"))
            then "<span>Belongs to default module.</span>"
            else "<span>Belongs to&nbsp; ``buildLink(mod, mod.nameAsString)``
                  &nbsp;<tt>``color("\"" + mod.version + "\"", Colors.strings)``</tt>.</span>";
        
        addIconAndText(buffer, mod, label);
    }
}
