import ceylon.collection {
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Type,
    TypeDeclaration,
    TypedDeclaration,
    Unit,
    ModelUtil
}

object correctionUtil {
    
    deprecated ("use [[com.redhat.ceylon.compiler.typechecker.util::NormalizedLevenshtein]]")
    shared Integer levenshteinDistance(String x, String y) {
        value n = x.size; // length of s
        value m = y.size; // length of t
        if (n == 0) {
            return m;
        }
        if (m == 0) {
            return n;
        }
        variable value p = Array.ofSize(n + 1, 0); //'previous' cost array, horizontally
        variable value d = Array.ofSize(n + 1, 0); // cost array, horizontally
        variable Array<Integer> _d;  //placeholder to assist in swapping p and d
        
        variable Character t_j; // jth character of t
        
        variable Integer cost; // cost
        
        for  (i in 0..n) {
            p[i] = i;
        }

        for (j in 1..m) {
            t_j = y.get(j - 1) else ' ';
            d[0] = j;
            
            for (i in 1..n) {
                cost = if ((x.get(i - 1) else ' ') == t_j) then 0 else 1;
                // minimum of cell to the left+1, to the top+1, diagonally left and up +cost
                d[i] = min({(d.get(i - 1) else 0) + 1, (p.get(i) else 0) + 1, (p.get(i - 1) else 0) + cost});
            }

            // copy current distance counts to 'previous row' distance counts
            _d = p;
            p = d;
            d = _d;
        }

        // our last action in the above loop was to switch d and p, so p now 
        // actually has the most recent cost counts
        assert(exists result = p.get(n));
        return result;
    }
    
    shared Tree.Body? getClassOrInterfaceBody(Tree.Declaration decNode)
            => switch (decNode)
            case (is Tree.ClassDefinition) decNode.classBody
            case (is Tree.InterfaceDefinition) decNode.interfaceBody
            case (is Tree.ObjectDefinition) decNode.classBody
            else null;
    
    shared Tree.CompilationUnit getRootNode(PhasedUnit unit) {
        //value ce = currentEditor;
        // TODO if (is CeylonEditor ce) {
        //    value editor = ce;
        //    value cpc = editor.parseController;
        //    if (exists cpc) {
        //        value rn = cpc.rootNode;
        //        if (exists rn) {
        //            value u = rn.unit;
        //            if (u.equals(unit.unit)) {
        //                return rn;
        //            }
        //        }
        //    }
        //}
        return unit.compilationUnit;
    }
    
    shared String asIntersectionTypeString({Type*} types) {
        value missingSatisfiedTypesText = StringBuilder();
        for (missingSatisfiedType in types) {
            if (missingSatisfiedTypesText.size != 0) {
                missingSatisfiedTypesText.append(" & ");
            }
            missingSatisfiedTypesText.append(missingSatisfiedType.asString());
        }
        return missingSatisfiedTypesText.string;
    }
    
    shared String defaultValue(Unit unit, Type? type) {
        if (ModelUtil.isTypeUnknown(type)) {
            return "nothing";
        }
        if (unit.isOptionalType(type)) {
            return "null";
        }
        assert (exists type);
        if (type.typeAlias || type.classOrInterface, type.declaration.\ialias) {
            return defaultValue(unit, type.extendedType);
        }
        if (type.\iclass) {
            value c = type.declaration;
            if (c.equals(unit.booleanDeclaration)) {
                return "false";
            } else if (c.equals(unit.integerDeclaration)) {
                return "0";
            } else if (c.equals(unit.floatDeclaration)) {
                return "0.0";
            } else if (c.equals(unit.stringDeclaration)) {
                return "\"\"";
            } else if (c.equals(unit.byteDeclaration)) {
                return "0.byte";
            } else if (c.equals(unit.tupleDeclaration)) {
                value minimumLength = unit.getTupleMinimumLength(type);
                value tupleTypes = unit.getTupleElementTypes(type);
                value sb = StringBuilder();
                variable value i = 0;
                while (i < minimumLength) {
                    sb.append(if (sb.size == 0) then "[" else ", ");
                    variable value currentType = tupleTypes.get(i);
                    if (unit.isSequentialType(currentType)) {
                        currentType = unit.getSequentialElementType(currentType);
                    }
                    sb.append(defaultValue(unit, currentType));
                    i++;
                }
                sb.append("]");
                return sb.string;
            } else if (unit.isSequentialType(type)) {
                value sb = StringBuilder();
                sb.append("[");
                if (!unit.emptyType.isSubtypeOf(type)) {
                    sb.append(defaultValue(unit, unit.getSequentialElementType(type)));
                }
                sb.append("]");
                return sb.string;
            } else if (unit.isIterableType(type)) {
                value sb = StringBuilder();
                sb.append("{");
                if (!unit.emptyType.isSubtypeOf(type)) {
                    sb.append(defaultValue(unit, unit.getIteratedType(type)));
                }
                sb.append("}");
                return sb.string;
            } else {
                return "nothing";
            }
        } else {
            return "nothing";
        }
    }
    
    shared Region computeSelection<Region>(Integer offset, String def, Region newRegion(Integer start, Integer length)) {
        Integer length;
        variable value loc = def.firstInclusion("= nothing");
        if (!exists l = loc) {
            loc = def.firstInclusion("=> nothing");
        }
        if (!exists l = loc) {
            loc = def.firstInclusion("= ");
            if (!exists lo = loc) {
                loc = def.firstInclusion("=> ");
            }
            if (!exists lo = loc) {
                loc = (def.firstInclusion("{") else -1) + 1;
                length = 0;
            } else {
                loc = (def.firstInclusion(" ", loc else 0) else -1) + 1;
                value semi = def.firstInclusion(";", loc else 0);
                value _loc = loc else 0;
                length = if (!exists semi) then def.size - _loc else semi - _loc;
            }
        } else {
            loc = (def.firstInclusion(" ", loc else 0) else -1) + 1;
            length = 7;
        }
        return newRegion(offset + (loc else 0), length);
    }
    
    shared String getDescription(Declaration dec) {
        variable value desc = "'" + dec.name + "'";
        value container = dec.container;
        if (is TypeDeclaration container) {
            value td = container;
            desc += " in '"+td.name+"'";
        }
        return desc;
    }
    
    shared Node getBeforeParenthesisNode(Tree.Declaration decNode) {
        variable Node n = decNode.identifier;
        if (is Tree.TypeDeclaration decNode) {
            value td = decNode;
            Tree.TypeParameterList? tpl = td.typeParameterList;
            if (exists tpl) {
                n = tpl;
            }
        }
        if (is Tree.AnyMethod decNode) {
            value am = decNode;
            Tree.TypeParameterList? tpl = am.typeParameterList;
            if (exists tpl) {
                n = tpl;
            }
        }
        return n;
    }
    
    shared List<TypedDeclaration> collectUninitializedMembers(Tree.Body? body) {
        value uninitialized = ArrayList<TypedDeclaration>();
        if (exists body) {
            for (st in body.statements) {
                switch (st)
                case (is Tree.AttributeDeclaration) {
                    if (!st.specifierOrInitializerExpression exists) {
                        value v = st.declarationModel;
                        if (!v.formal) {
                            uninitialized.add(v);
                        }
                    }
                }
                case (is Tree.MethodDeclaration) {
                    if (!st.specifierExpression exists) {
                        value m = st.declarationModel;
                        if (!m.formal) {
                            uninitialized.add(m);
                        }
                    }
                }
                case (is Tree.SpecifierStatement) {
                    if (is Tree.BaseMemberExpression term
                            = st.baseMemberExpression,
                        is TypedDeclaration d = term.declaration) {
                        uninitialized.remove(d);
                    }
                }
                else {}
            }
        }
        return uninitialized;
    }
}
