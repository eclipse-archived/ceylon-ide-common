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
            p.set(i, i);
        }

        for (j in 1..m) {
            t_j = y.get(j - 1) else ' ';
            d.set(0, j);
            
            for (i in 1..n) {
                cost = if ((x.get(i - 1) else ' ') == t_j) then 0 else 1;
                // minimum of cell to the left+1, to the top+1, diagonally left and up +cost
                d.set(i, min({(d.get(i - 1) else 0) + 1, (p.get(i) else 0) + 1, (p.get(i - 1) else 0) + cost}));
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
    
    shared Tree.Body? getClassOrInterfaceBody(Tree.Declaration decNode) {
        if (is Tree.ClassDefinition decNode) {
            value cd = decNode;
            return cd.classBody;
        } else if (is Tree.InterfaceDefinition decNode) {
            value id = decNode;
            return id.interfaceBody;
        } else if (is Tree.ObjectDefinition decNode) {
            value od = decNode;
            return od.classBody;
        } else {
            return null;
        }
    }
    
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
    
    shared String defaultValue(Unit unit, Type? t) {
        if (ModelUtil.isTypeUnknown(t)) {
            return "nothing";
        }
        if (unit.isOptionalType(t)) {
            return "null";
        }
        assert (exists t);
        if (t.typeAlias || t.classOrInterface, t.declaration.\ialias) {
            return defaultValue(unit, t.extendedType);
        }
        if (t.\iclass) {
            value c = t.declaration;
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
                value minimumLength = unit.getTupleMinimumLength(t);
                value tupleTypes = unit.getTupleElementTypes(t);
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
            } else if (unit.isSequentialType(t)) {
                value sb = StringBuilder();
                sb.append("[");
                if (!unit.emptyType.isSubtypeOf(t)) {
                    sb.append(defaultValue(unit, unit.getSequentialElementType(t)));
                }
                sb.append("]");
                return sb.string;
            } else if (unit.isIterableType(t)) {
                value sb = StringBuilder();
                sb.append("{");
                if (!unit.emptyType.isSubtypeOf(t)) {
                    sb.append(defaultValue(unit, unit.getIteratedType(t)));
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
            value statements = body.statements;
            for (st in statements) {
                if (is Tree.AttributeDeclaration st) {
                    if (!exists a = st.specifierOrInitializerExpression) {
                        value v = st.declarationModel;
                        if (!v.formal) {
                            uninitialized.add(v);
                        }
                    }
                } else if (is Tree.MethodDeclaration st) {
                    if (!exists sp = st.specifierExpression) {
                        value m = st.declarationModel;
                        if (!m.formal) {
                            uninitialized.add(m);
                        }
                    }
                } else if (is Tree.SpecifierStatement st) {
                    value term = st.baseMemberExpression;
                    if (is Tree.BaseMemberExpression term, 
                        is TypedDeclaration d = term.declaration) {
                        uninitialized.remove(d);
                    }
                }
            }
        }
        return uninitialized;
    }
}
