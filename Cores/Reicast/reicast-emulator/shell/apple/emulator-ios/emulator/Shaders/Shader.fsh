//
//  Shader.fsh
//  emulator
//
//  Created by Lounge Katt on 2/6/14.
//  Copyright (c) 2014 Lounge Katt. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
