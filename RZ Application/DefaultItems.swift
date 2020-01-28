//
//  DefaultItems.swift
//  Render-Z
//
//  Created by Markus Moenig on 16/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

let defaultRender2D = """
    {"values":{},"componentType":4,"sequence":{"items":[],"name":"Idle","totalFrames":100,"uuid":"934EE847-6545-4663-B11F-B2ACB262D466"},"subComponent":null,"selected":"31A6FB46-316E-4476-A496-27DD2D577F02","artistPropertyNames":["253D30F0-91EB-4228-B793-0DB12A58A21E","Anti Aliasing"],"properties":["253D30F0-91EB-4228-B793-0DB12A58A21E"],"functions":[{"body":[{"fragment":{"uuid":"253D30F0-91EB-4228-B793-0DB12A58A21E","name":"pixelSize","fragmentType":3,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4],"arguments":[],"typeName":"float","evaluatesTo":null},"assignment":{"uuid":"94BDC7E1-49AB-40B7-96A6-228DA7DFB762","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"uuid":"8F869EAC-C4C9-4B59-8344-8AABC4C19237","comment":"","statement":{"fragments":[{"uuid":"37BAE6C1-30F2-44F9-9DF4-8E22F600A643","name":"float","fragmentType":7,"argumentFormat":["float"],"referseTo":null,"values":{"min":0,"value":2.09814453125,"precision":0,"max":10},"isSimplified":false,"qualifier":"","properties":[0,1,2],"arguments":[],"typeName":"float","evaluatesTo":"float"}],"uuid":"502E5466-2A37-47AE-8598-FF37339862E3","statementType":0},"blockType":3},{"fragment":{"uuid":"4C7DD597-87C9-49E2-BE95-C9914CD19690","name":"smooth","fragmentType":3,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4],"arguments":[],"typeName":"float","evaluatesTo":null},"assignment":{"uuid":"922D7980-2787-46DA-9E4E-ED0F29167199","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"uuid":"B19E509A-FFAC-4773-9C84-FABE7AD15657","comment":"","statement":{"fragments":[{"uuid":"660E24FD-660B-458C-A41A-4DE13F80372A","name":"smoothstep","fragmentType":8,"argumentFormat":["float|float2|float3|float4","float|float2|float3|float4","float"],"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,2,2],"arguments":[{"fragments":[{"uuid":"32BB2BF8-9D29-4C16-B7E7-C04FF0EEFFCB","name":"float","fragmentType":7,"argumentFormat":["float"],"referseTo":null,"values":{"min":0,"value":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,2],"arguments":[],"typeName":"float","evaluatesTo":"float"}],"uuid":"A48066EE-199A-4DB5-83BD-E3BA76538514","statementType":1},{"fragments":[{"uuid":"F3586D05-83D9-444B-B2B7-21D827DD48D9","name":"pixelSize","fragmentType":4,"argumentFormat":null,"referseTo":"253D30F0-91EB-4228-B793-0DB12A58A21E","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4,2],"arguments":[],"typeName":"float","evaluatesTo":null}],"uuid":"314B6E5D-108E-4FCA-A847-E3CA43A26864","statementType":1},{"fragments":[{"uuid":"1C6AE515-0282-49B2-84AC-E40A1682AB8D","name":"distance","fragmentType":4,"argumentFormat":null,"referseTo":"3D7981E2-E440-4AA8-9FD3-65FCBB8B83E7","values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3,2],"arguments":[],"typeName":"float","evaluatesTo":"float"}],"uuid":"69ADE397-ECF1-4012-9D66-22B3A6514D93","statementType":1}],"typeName":"float","evaluatesTo":"input0"}],"uuid":"E89ECB8D-CF45-4560-9367-C78A758EA9E2","statementType":0},"blockType":3},{"fragment":{"uuid":"053CE36E-7E7B-4800-9EE2-C37E17F2ACD9","name":"outColor","fragmentType":5,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,4,1],"arguments":[],"typeName":"float4","evaluatesTo":"float4"},"assignment":{"uuid":"E04EF5B0-2352-4C87-9524-83FD562CB092","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"uuid":"B45FD5C2-ACA6-44DF-A105-E74752E2F944","comment":"","statement":{"fragments":[{"uuid":"EE7AC412-3404-484B-A882-8E426B5B0787","name":"mix","fragmentType":8,"argumentFormat":["float|float2|float3|float4","float|float2|float3|float4","float"],"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,2],"arguments":[{"fragments":[{"uuid":"E8678F4B-A58A-4994-A613-2A93931F1F35","name":"matColor","fragmentType":4,"argumentFormat":["float4"],"referseTo":"D4B41D0D-CF19-4A4C-BD83-9654B18A5E78","values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3,2],"arguments":[],"typeName":"float4","evaluatesTo":"float4"}],"uuid":"E378366A-DB17-4AC4-B6B7-0CE12BDF3E72","statementType":1},{"fragments":[{"uuid":"40314465-0B1B-493D-AE04-12B09AE555F8","name":"backColor","fragmentType":4,"argumentFormat":["float4"],"referseTo":"D6A9D0E0-F4A9-4879-92A8-0F61B750023D","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3,2],"arguments":[],"typeName":"float4","evaluatesTo":"float4"}],"uuid":"2C78AD5F-F55D-4D7A-B357-CA43DDA47110","statementType":1},{"fragments":[{"uuid":"9F6E08B6-E550-4653-B2C5-57B167547857","name":"smooth","fragmentType":4,"argumentFormat":null,"referseTo":"4C7DD597-87C9-49E2-BE95-C9914CD19690","values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4,2],"arguments":[],"typeName":"float","evaluatesTo":null}],"uuid":"763D7346-1AE2-4CE8-87E1-AF330652C8E1","statementType":1}],"typeName":"float4","evaluatesTo":"input0"}],"uuid":"0179FC51-B39F-4514-AA72-A03313D5031B","statementType":0},"blockType":2}],"uuid":"31A6FB46-316E-4476-A496-27DD2D577F02","comment":"Computes the pixel color for the given material","name":"computeColor","header":{"fragment":{"uuid":"31C66278-AE26-4C62-B574-599A6128D42B","name":"computeColor","fragmentType":2,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[],"arguments":[],"typeName":"void","evaluatesTo":null},"assignment":{"uuid":"F370401E-9241-4E67-B582-EC04F7AFCFD1","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"uuid":"50A41C16-7EB8-4EEE-A8E1-7DED990EC745","comment":"","statement":{"fragments":[{"uuid":"158826CB-83FB-4AC8-83D8-CC3BD2B7B132","name":"uv","fragmentType":3,"argumentFormat":["float2"],"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3],"arguments":[],"typeName":"float2","evaluatesTo":"float2"},{"uuid":"EA06DDF4-D1D7-4ED3-B899-F399DE597F0E","name":"size","fragmentType":3,"argumentFormat":["float2"],"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3],"arguments":[],"typeName":"float2","evaluatesTo":"float2"},{"uuid":"3D7981E2-E440-4AA8-9FD3-65FCBB8B83E7","name":"distance","fragmentType":3,"argumentFormat":["float"],"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3],"arguments":[],"typeName":"float","evaluatesTo":"float"},{"uuid":"D6A9D0E0-F4A9-4879-92A8-0F61B750023D","name":"backColor","fragmentType":3,"argumentFormat":["float4"],"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3],"arguments":[],"typeName":"float4","evaluatesTo":"float4"},{"uuid":"D4B41D0D-CF19-4A4C-BD83-9654B18A5E78","name":"matColor","fragmentType":3,"argumentFormat":["float4"],"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3],"arguments":[],"typeName":"float4","evaluatesTo":"float4"}],"uuid":"66C5DC58-9D1A-47F2-BF8D-1829BCE93C44","statementType":1},"blockType":1},"functionType":5}],"uuid":"400BBED8-41C8-4CE8-A176-18DEB099C081","libraryName":"Solid Color","libraryComment":"Color rendering with anti-aliasing"}
"""

let defaultBoolean = """
{"uuid":"F5EC41E0-08F2-4F8E-AB08-2D22292FA3E0","subComponent":null,"functions":[{"body":[{"assignment":{"uuid":"1C5C80D0-5AD5-4EBF-AA24-953CF1F6D689","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"089BA240-4887-43A3-9244-72A3D0C12E09","name":"shapeA","fragmentType":4,"argumentFormat":["float4"],"referseTo":"32D0364B-D809-40C6-B391-48866720AE5F","values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3,2],"arguments":[],"typeName":"float4","evaluatesTo":"float4"}],"uuid":"E4E323A3-B0C4-475F-90A5-3AF782E10F0E","statementType":0},"children":[],"blockType":3,"uuid":"AA6ECA25-F3A9-4FD8-9739-3093711FC0B6","comment":"","fragment":{"uuid":"9E0156F9-7253-4791-A89B-D855062ABF41","name":"shape","fragmentType":3,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4],"arguments":[],"typeName":"float4","evaluatesTo":null}},{"assignment":{"uuid":"6D3B06C8-1529-46A5-9F71-144ECC76B88A","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[],"uuid":"D6D9AECE-1F15-4679-9883-B1D9F7E20450","statementType":0},"children":[],"blockType":0,"uuid":"9DB16FEF-DB7C-41C9-98A5-B97335CFE9EA","comment":"","fragment":{"uuid":"E1ED65A7-E3FD-4F2B-ABD8-6BA33842AB6F","name":"","fragmentType":0,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null}},{"assignment":{"uuid":"A8AA2DAA-F37A-47A8-AD3C-E7D235176657","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[],"uuid":"24E29C8E-4678-4817-934C-10C193F62CF1","statementType":0},"children":[{"assignment":{"uuid":"99F374D7-C748-4E64-8712-DFBC414A6C8B","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"D9EAB7F7-1D8A-4C7F-89DF-ADA1917E507F","name":"shapeB","fragmentType":4,"argumentFormat":["float4"],"referseTo":"7FA95ED7-414A-4630-BDE0-A19B748EAA5B","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3,2],"arguments":[],"typeName":"float4","evaluatesTo":"float4"}],"uuid":"62ED128A-B470-4154-8D46-CC11C4FE2358","statementType":0},"children":[],"blockType":4,"uuid":"B5F4B357-5649-4CD5-B26F-208E27E18AA1","comment":"","fragment":{"uuid":"8E91B8A3-C519-4648-964D-7834507AA04E","name":"shape","fragmentType":4,"argumentFormat":null,"referseTo":"9E0156F9-7253-4791-A89B-D855062ABF41","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4],"arguments":[],"typeName":"float4","evaluatesTo":null}},{"assignment":{"uuid":"F80FEFB4-D7DD-472F-8518-3DEC4ADE823C","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[],"uuid":"8BE07333-4F8D-430D-9809-29B57953F80A","statementType":0},"children":[],"blockType":0,"uuid":"5234EC9A-6D10-4A36-8716-95B55947E42D","comment":"","fragment":{"uuid":"F2087E27-4042-4427-BE9F-3600E23E1881","name":"","fragmentType":0,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null}}],"blockType":5,"uuid":"D6F8A6B6-6DED-4F75-AFAE-81F6C05567A2","comment":"","fragment":{"uuid":"C980EA26-4844-4093-A564-4F4378026519","name":"if","fragmentType":14,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[{"fragments":[{"uuid":"441699FD-8084-4BA1-8C07-0C6D5E94B922","name":"shapeB","fragmentType":4,"argumentFormat":null,"referseTo":"7FA95ED7-414A-4630-BDE0-A19B748EAA5B","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"x","properties":[0,1,3,2],"arguments":[],"typeName":"float4","evaluatesTo":"float4"},{"uuid":"0C2EAC12-15EA-400D-9187-81173314B845","name":"<","fragmentType":13,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"bool","evaluatesTo":null},{"uuid":"B55C9429-A75A-414A-B675-9523CDB5D0BB","name":"shapeA","fragmentType":4,"argumentFormat":null,"referseTo":"32D0364B-D809-40C6-B391-48866720AE5F","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"x","properties":[0,1,3,2],"arguments":[],"typeName":"float4","evaluatesTo":"float4"}],"uuid":"DA239279-176A-4795-9D74-9916A8F5C76E","statementType":2}],"typeName":"bool","evaluatesTo":null}},{"assignment":{"uuid":"6C0AE6E0-9196-4D35-B274-AC218BE2FC7A","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"75AFF38A-AA12-4B5F-94AC-23DF18B81719","name":"shape","fragmentType":4,"argumentFormat":null,"referseTo":"9E0156F9-7253-4791-A89B-D855062ABF41","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4,2],"arguments":[],"typeName":"float4","evaluatesTo":null}],"uuid":"900660B0-7E69-47F7-AD71-052201F46B41","statementType":0},"children":[],"blockType":2,"uuid":"2B608058-CFB5-4A93-8784-2D2A83E1C47E","comment":"","fragment":{"uuid":"4D4484CD-FF40-4286-9FF1-DF0F00BA846F","name":"outShape","fragmentType":5,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,4,1],"arguments":[],"typeName":"float4","evaluatesTo":"float4"}}],"uuid":"95C2FD10-30EE-4404-B231-84AB65884F3D","comment":"Choose between the two shapes based on their distances stored in .x","name":"booleanOperator","header":{"assignment":{"uuid":"87282542-BFB0-423F-8DEB-E7D0666EAFA6","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"32D0364B-D809-40C6-B391-48866720AE5F","name":"shapeA","fragmentType":3,"argumentFormat":["float4"],"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3],"arguments":[],"typeName":"float4","evaluatesTo":"float4"},{"uuid":"7FA95ED7-414A-4630-BDE0-A19B748EAA5B","name":"shapeB","fragmentType":3,"argumentFormat":["float4"],"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3],"arguments":[],"typeName":"float4","evaluatesTo":"float4"}],"uuid":"993D59D7-7FB3-4B0C-AB01-F2B8C12C98BB","statementType":1},"children":[],"blockType":1,"uuid":"6472D479-3863-488F-821D-84F33E13355C","comment":"","fragment":{"uuid":"E4953132-CF34-41E1-A226-AFE3D0D96E24","name":"","fragmentType":2,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[],"arguments":[],"typeName":"void","evaluatesTo":null}},"functionType":7}],"libraryComment":"Merges two shapes","values":{},"componentType":6,"libraryName":"Merge","artistPropertyNames":[],"properties":[],"sequence":{"items":[],"name":"Idle","totalFrames":100,"uuid":"77A4D3E3-3BEF-4BA2-A6B8-99C4DA2A6A3B"},"selected":"95C2FD10-30EE-4404-B231-84AB65884F3D","propertyGizmoMap":[]}
"""

let defaultCamera2D =
"""
{"uuid":"F35C62BC-7667-4FCA-A05B-09F91B12B365","subComponent":null,"libraryCategory":"Noise","functions":[{"name":"camera","header":{"assignment":{"uuid":"0D8CB756-A65C-4CCB-9A3B-AB3D0E200D3B","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"22E4CDC5-64A1-45ED-A9FF-0BDA45E05EB0","name":"position","fragmentType":3,"argumentFormat":["float2"],"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3],"arguments":[],"typeName":"float2","evaluatesTo":"float2"}],"uuid":"A9DFB15A-F72F-46E2-AE4B-1D49909B5D35","statementType":1},"children":[],"blockType":1,"uuid":"6E5609F3-FBFC-4468-93D3-9FC327C280A7","comment":"","fragment":{"uuid":"963E7676-CB9B-4309-A65B-A5FB758FEA27","name":"camera","fragmentType":2,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[],"arguments":[],"typeName":"void","evaluatesTo":null}},"functionType":8,"libraryCategory":"Noise","uuid":"85797749-EC3D-4AF6-8299-970F5808A667","libraryComment":"","body":[{"assignment":{"uuid":"9B32EDAB-AAC4-46A9-B0B8-B0D0EEEA8F53","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"798BF0C1-72A0-470B-B25E-D1854FD2ABB4","name":"float","fragmentType":7,"argumentFormat":["float"],"referseTo":null,"values":{"min":-1000,"value":0,"precision":3,"max":1000},"isSimplified":false,"qualifier":"","properties":[0,1,2],"arguments":[],"typeName":"float","evaluatesTo":"float"}],"uuid":"6B49C2BE-9B47-4DE7-9AD9-53DCB10BA04D","statementType":0},"children":[],"blockType":3,"uuid":"FD612237-D05D-4D71-8DBC-E8FA60BEBD04","comment":"","fragment":{"uuid":"395F2EBA-2DCE-4FD5-A92D-3EBA7A7E85FF","name":"cameraX","fragmentType":3,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4],"arguments":[],"typeName":"float","evaluatesTo":null}},{"assignment":{"uuid":"414AFF1E-38F8-4F78-82D1-9467C52E85F9","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"BD1E75BC-D9B4-4CCC-8E6B-7662FD238EEB","name":"float","fragmentType":7,"argumentFormat":["float"],"referseTo":null,"values":{"value":0,"min":-1000,"precision":3,"max":1000},"isSimplified":false,"qualifier":"","properties":[0,1,2],"arguments":[],"typeName":"float","evaluatesTo":"float"}],"uuid":"D3FE14D1-35CD-4127-8E75-6A2456BFE851","statementType":0},"children":[],"blockType":3,"uuid":"26496283-3A52-4F88-88B3-08CDDFC2E32E","comment":"","fragment":{"uuid":"22950FF0-B6C9-4AB4-9D14-728B76A373AA","name":"cameraY","fragmentType":3,"argumentFormat":null,"referseTo":"395F2EBA-2DCE-4FD5-A92D-3EBA7A7E85FF","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4],"arguments":[],"typeName":"float","evaluatesTo":null}},{"assignment":{"uuid":"4EBF5891-2B1F-4AB9-947A-99E37E92AFA6","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"5270FE64-F269-4D1D-B914-8911825EDE8B","name":"float","fragmentType":7,"argumentFormat":["float"],"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":20},"isSimplified":false,"qualifier":"","properties":[0,1,2],"arguments":[],"typeName":"float","evaluatesTo":"float"}],"uuid":"318952D5-2E4C-4AF8-9B8A-3B3C39088A18","statementType":0},"children":[],"blockType":3,"uuid":"9C87A1DF-1510-4C96-ADB0-B6AB39132225","comment":"","fragment":{"uuid":"CF6FDC2F-0D78-4FB0-92A8-58B38A9D5ABB","name":"scale","fragmentType":3,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4],"arguments":[],"typeName":"float","evaluatesTo":null}},{"assignment":{"uuid":"E0D90C2F-F2E2-4781-934D-567BB2E2F6F0","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[],"uuid":"612C0E08-2FDD-457A-9937-E0DFC008BA0D","statementType":0},"children":[],"blockType":0,"uuid":"0099842B-4390-4475-AA08-11A75DF94734","comment":"","fragment":{"uuid":"DBEA4458-2343-4F50-9DE5-F878A125292B","name":"","fragmentType":0,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null}},{"assignment":{"uuid":"F83F29C7-5B22-4BCA-B677-82EED31831CE","name":"=","fragmentType":12,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"","evaluatesTo":null},"statement":{"fragments":[{"uuid":"FEAE8D81-DBE1-4DED-A88D-44D5C0893B3B","name":"(","fragmentType":10,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"float2","evaluatesTo":null},{"uuid":"09A6C795-5543-4AFE-B679-BEB620B579E9","name":"position","fragmentType":4,"argumentFormat":["float2"],"referseTo":"22E4CDC5-64A1-45ED-A9FF-0BDA45E05EB0","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,3,2],"arguments":[],"typeName":"float2","evaluatesTo":"float2"},{"uuid":"C33600B8-E0EB-4EF9-8ECE-BB63C42C0A1F","name":"+","fragmentType":9,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"float2","evaluatesTo":null},{"uuid":"DFF66EC0-0182-477D-BCDA-21EB8C4E9CB7","name":"float2","fragmentType":6,"argumentFormat":["float2"],"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"x","properties":[0,1,2,2],"arguments":[{"fragments":[{"uuid":"78D0D73A-81D3-4A95-850A-E93D7A1B8AC0","name":"cameraX","fragmentType":4,"argumentFormat":null,"referseTo":"395F2EBA-2DCE-4FD5-A92D-3EBA7A7E85FF","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4,2],"arguments":[],"typeName":"float","evaluatesTo":null}],"uuid":"540D9BA4-9F47-4B25-883A-B41341B7E326","statementType":0},{"fragments":[{"uuid":"BD97769D-F555-4194-B849-E292146CB207","name":"cameraY","fragmentType":4,"argumentFormat":null,"referseTo":"22950FF0-B6C9-4AB4-9D14-728B76A373AA","values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4,2],"arguments":[],"typeName":"float","evaluatesTo":null}],"uuid":"32F4A168-37F5-4EA7-8D71-853E868A87CD","statementType":0}],"typeName":"float2","evaluatesTo":"float2"},{"uuid":"FEAE8D81-DBE1-4DED-A88D-44D5C0893B3B","name":")","fragmentType":11,"argumentFormat":null,"referseTo":null,"values":{"value":1,"min":0,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"float2","evaluatesTo":null},{"uuid":"5CB1FF66-25E9-4AC8-AB4D-85FC4530F96F","name":"*","fragmentType":9,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0],"arguments":[],"typeName":"float2","evaluatesTo":null},{"uuid":"F6EC06CA-1890-4658-978F-49616F858321","name":"zoom","fragmentType":4,"argumentFormat":null,"referseTo":"CF6FDC2F-0D78-4FB0-92A8-58B38A9D5ABB","values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,1,4,2],"arguments":[],"typeName":"float","evaluatesTo":null}],"uuid":"7F0246B9-245E-448D-A461-6C8752F5616B","statementType":0},"children":[],"blockType":2,"uuid":"8B3F30D6-AE60-419A-B383-B6B934CCF36B","comment":"","fragment":{"uuid":"B09BDB9F-E78C-4CC3-94A1-02584A5A269A","name":"outPosition","fragmentType":5,"argumentFormat":null,"referseTo":null,"values":{"min":0,"value":1,"precision":3,"max":1},"isSimplified":false,"qualifier":"","properties":[0,4,1],"arguments":[],"typeName":"float2","evaluatesTo":"float2"}}],"libraryName":"","comment":"Translates an incoming position."}],"libraryComment":"Default Camera with a position and scale","componentType":8,"values":{},"libraryName":"Camera","artistPropertyNames":["22950FF0-B6C9-4AB4-9D14-728B76A373AA","Y","395F2EBA-2DCE-4FD5-A92D-3EBA7A7E85FF","X"],"properties":["395F2EBA-2DCE-4FD5-A92D-3EBA7A7E85FF","22950FF0-B6C9-4AB4-9D14-728B76A373AA"],"sequence":{"items":[],"name":"Idle","totalFrames":100,"uuid":"F2FF8368-700D-43F8-B4C7-D060ADEE7D34"},"selected":"85797749-EC3D-4AF6-8299-970F5808A667","propertyGizmoMap":[]}
"""
