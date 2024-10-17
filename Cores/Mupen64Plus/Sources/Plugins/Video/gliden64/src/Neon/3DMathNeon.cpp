#include "3DMath.h"
#include <cmath>
#include "Log.h"
#include "Types.h"
#include <arm_neon.h>

void MultMatrix( float m0[4][4], float m1[4][4], float dest[4][4])
{
    // Load m0
    float32x4x4_t _m0;
    _m0.val[0] = vld1q_f32(m0[0]);
    _m0.val[1] = vld1q_f32(m0[1]);
    _m0.val[2] = vld1q_f32(m0[2]);
    _m0.val[3] = vld1q_f32(m0[3]);

    // Load m1
    float32x4x4_t _m1;
    _m1.val[0] = vld1q_f32(m1[0]);
    _m1.val[1] = vld1q_f32(m1[1]);
    _m1.val[2] = vld1q_f32(m1[2]);
    _m1.val[3] = vld1q_f32(m1[3]);

    float32x4x4_t _dest;

    _dest.val[0] = vmulq_n_f32(_m0.val[0], _m1.val[0][0]);
    _dest.val[1] = vmulq_n_f32(_m0.val[0], _m1.val[1][0]);
    _dest.val[2] = vmulq_n_f32(_m0.val[0], _m1.val[2][0]);
    _dest.val[3] = vmulq_n_f32(_m0.val[0], _m1.val[3][0]);
    _dest.val[0] = vmlaq_n_f32(_dest.val[0], _m0.val[1], _m1.val[0][1]);
    _dest.val[1] = vmlaq_n_f32(_dest.val[1], _m0.val[1], _m1.val[1][1]);
    _dest.val[2] = vmlaq_n_f32(_dest.val[2], _m0.val[1], _m1.val[2][1]);
    _dest.val[3] = vmlaq_n_f32(_dest.val[3], _m0.val[1], _m1.val[3][1]);
    _dest.val[0] = vmlaq_n_f32(_dest.val[0], _m0.val[2], _m1.val[0][2]);
    _dest.val[1] = vmlaq_n_f32(_dest.val[1], _m0.val[2], _m1.val[1][2]);
    _dest.val[2] = vmlaq_n_f32(_dest.val[2], _m0.val[2], _m1.val[2][2]);
    _dest.val[3] = vmlaq_n_f32(_dest.val[3], _m0.val[2], _m1.val[3][2]);
    _dest.val[0] = vmlaq_n_f32(_dest.val[0], _m0.val[3], _m1.val[0][3]);
    _dest.val[1] = vmlaq_n_f32(_dest.val[1], _m0.val[3], _m1.val[1][3]);
    _dest.val[2] = vmlaq_n_f32(_dest.val[2], _m0.val[3], _m1.val[2][3]);
    _dest.val[3] = vmlaq_n_f32(_dest.val[3], _m0.val[3], _m1.val[3][3]);

    vst1q_f32(dest[0], _dest.val[0]);
    vst1q_f32(dest[1], _dest.val[1]);
    vst1q_f32(dest[2], _dest.val[2]);
    vst1q_f32(dest[3], _dest.val[3]);
}

void MultMatrix2(float m0[4][4], float m1[4][4])
{
    MultMatrix(m0, m1, m0);
}

void TransformVectorNormalize(float vec[3], float mtx[4][4])
{
    // Load mtx
    float32x4x4_t _mtx;
    _mtx.val[0] = vld1q_f32(mtx[0]);
    _mtx.val[1] = vld1q_f32(mtx[1]);
    _mtx.val[2] = vld1q_f32(mtx[2]);
    _mtx.val[3] = vld1q_f32(mtx[3]);

    // Multiply and add
    float32x4_t product;
    product = vmulq_n_f32(_mtx.val[0], vec[0]);
    product = vmlaq_n_f32(product, _mtx.val[1], vec[1]);
    product = vmlaq_n_f32(product, _mtx.val[2], vec[2]);

    // Normalize
    float32x2_t product0 = {product[0],product[1]};
    float32x2_t product1 = {product[2],product[3]};
    float32x2_t temp;

    temp = vmul_f32(product0, product0);
    temp = vpadd_f32(temp, temp);
    temp = vmla_f32(temp, product1, product1);       // temp[0] is important

    float32x2_t recpSqrtEst;
    float32x2_t recp;
    float32x2_t prod;
    
    recpSqrtEst = vrsqrte_f32(temp);
    prod =        vmul_f32(recpSqrtEst,temp);
    recp =        vrsqrts_f32(prod,recpSqrtEst);
    recpSqrtEst = vmul_f32(recpSqrtEst,recp);
    prod =        vmul_f32(recpSqrtEst,temp);
    recp =        vrsqrts_f32(prod,recpSqrtEst);
    recpSqrtEst = vmul_f32(recpSqrtEst,recp);

    product = vmulq_n_f32(product, recpSqrtEst[0]);

    // Store mtx
    vec[0] = product[0];
    vec[1] = product[1];
    vec[2] = product[2];
}

void InverseTransformVectorNormalize(float src[3], float dst[3], float mtx[4][4])
{
    // Load mtx
    float32x4x4_t _mtx = vld4q_f32(mtx[0]);
    
    // Multiply and add
    float32x4_t product;
    product = vmulq_n_f32(_mtx.val[0], src[0]);
    product = vmlaq_n_f32(product, _mtx.val[1], src[1]);
    product = vmlaq_n_f32(product, _mtx.val[2], src[2]);

    // Normalize
    float32x2_t product0 = {product[0],product[1]};
    float32x2_t product1 = {product[2],product[3]};
    float32x2_t temp;

    temp = vmul_f32(product0, product0);
    temp = vpadd_f32(temp, temp);
    temp = vmla_f32(temp, product1, product1);       // temp[0] is important

    float32x2_t recpSqrtEst;
    float32x2_t recp;
    float32x2_t prod;
    
    recpSqrtEst = vrsqrte_f32(temp);
    prod =        vmul_f32(recpSqrtEst,temp);
    recp =        vrsqrts_f32(prod,recpSqrtEst);
    recpSqrtEst = vmul_f32(recpSqrtEst,recp);
    prod =        vmul_f32(recpSqrtEst,temp);
    recp =        vrsqrts_f32(prod,recpSqrtEst);
    recpSqrtEst = vmul_f32(recpSqrtEst,recp);

    product = vmulq_n_f32(product, recpSqrtEst[0]);

    // Store mtx
    dst[0] = product[0];
    dst[1] = product[1];
    dst[2] = product[2];
}

void InverseTransformVectorNormalize4(float src[4][3], float dst[4][3], float mtx[4][4])
{
    // Load mtx
    float32x4x4_t _mtx = vld4q_f32(mtx[0]);
    
    // Multiply and add
    float32x4x4_t product;
    product.val[0] = vmulq_n_f32(_mtx.val[0], src[0][0]);
    product.val[1] = vmulq_n_f32(_mtx.val[0], src[1][0]);
    product.val[2] = vmulq_n_f32(_mtx.val[0], src[2][0]);
    product.val[3] = vmulq_n_f32(_mtx.val[0], src[3][0]);
    product.val[0] = vmlaq_n_f32(product.val[0], _mtx.val[1], src[0][1]);
    product.val[1] = vmlaq_n_f32(product.val[1], _mtx.val[1], src[1][1]);
    product.val[2] = vmlaq_n_f32(product.val[2], _mtx.val[1], src[2][1]);
    product.val[3] = vmlaq_n_f32(product.val[3], _mtx.val[1], src[3][1]);
    product.val[0] = vmlaq_n_f32(product.val[0], _mtx.val[2], src[0][2]);
    product.val[1] = vmlaq_n_f32(product.val[1], _mtx.val[2], src[1][2]);
    product.val[2] = vmlaq_n_f32(product.val[2], _mtx.val[2], src[2][2]);
    product.val[3] = vmlaq_n_f32(product.val[3], _mtx.val[2], src[3][2]);

    // Normalize
    float32x2_t product00 = {product.val[0][0],product.val[0][1]};
    float32x2_t product01 = {product.val[0][2],product.val[0][3]};
    float32x2_t product10 = {product.val[1][0],product.val[1][1]};
    float32x2_t product11 = {product.val[1][2],product.val[1][3]};
    float32x2_t product20 = {product.val[2][0],product.val[2][1]};
    float32x2_t product21 = {product.val[2][2],product.val[2][3]};
    float32x2_t product30 = {product.val[3][0],product.val[3][1]};
    float32x2_t product31 = {product.val[3][2],product.val[3][3]};

    float32x2_t temp0;
    float32x2_t temp1;
    float32x2_t temp2;
    float32x2_t temp3;

    temp0 = vmul_f32(product00, product00);
    temp1 = vmul_f32(product10, product10);
    temp2 = vmul_f32(product20, product20);
    temp3 = vmul_f32(product30, product30);
    temp0 = vpadd_f32(temp0, temp0);
    temp1 = vpadd_f32(temp1, temp1);
    temp2 = vpadd_f32(temp2, temp2);
    temp3 = vpadd_f32(temp3, temp3);
    temp0 = vmla_f32(temp0, product01, product01);       // temp[0] is important
    temp1 = vmla_f32(temp1, product11, product11);       // temp[0] is important
    temp2 = vmla_f32(temp2, product21, product21);       // temp[0] is important
    temp3 = vmla_f32(temp3, product31, product31);       // temp[0] is important

    float32x4_t temp = {temp0[0], temp1[0], temp2[0], temp3[0]};

    float32x4_t recpSqrtEst;
    float32x4_t recp;
    float32x4_t prod;
    
    recpSqrtEst = vrsqrteq_f32(temp);
    prod =        vmulq_f32(recpSqrtEst,temp);
    recp =        vrsqrtsq_f32(prod,recpSqrtEst);
    recpSqrtEst = vmulq_f32(recpSqrtEst,recp);
    prod =        vmulq_f32(recpSqrtEst,temp);
    recp =        vrsqrtsq_f32(prod,recpSqrtEst);
    recpSqrtEst = vmulq_f32(recpSqrtEst,recp);

    product.val[0] = vmulq_n_f32(product.val[0], recpSqrtEst[0]);
    product.val[1] = vmulq_n_f32(product.val[1], recpSqrtEst[1]);
    product.val[2] = vmulq_n_f32(product.val[2], recpSqrtEst[2]);
    product.val[3] = vmulq_n_f32(product.val[3], recpSqrtEst[3]);

    // Store mtx
    dst[0][0] = product.val[0][0];
    dst[0][1] = product.val[0][1];
    dst[0][2] = product.val[0][2];
    dst[1][0] = product.val[1][0];
    dst[1][1] = product.val[1][1];
    dst[1][2] = product.val[1][2];
    dst[2][0] = product.val[2][0];
    dst[2][1] = product.val[2][1];
    dst[2][2] = product.val[2][2];
    dst[3][0] = product.val[3][0];
    dst[3][1] = product.val[3][1];
    dst[3][2] = product.val[3][2];
}

void InverseTransformVectorNormalize7(float src[4][3], float dst[4][3], float mtx[4][4])
{
    // Load mtx
    float32x4x4_t _mtx = vld4q_f32(mtx[0]);
    
    // Multiply and add
    float32x4x4_t product0;
    float32x4x4_t product1;

    product0.val[0] = vmulq_n_f32(_mtx.val[0], src[0][0]);
    product0.val[1] = vmulq_n_f32(_mtx.val[0], src[1][0]);
    product0.val[2] = vmulq_n_f32(_mtx.val[0], src[2][0]);
    product0.val[3] = vmulq_n_f32(_mtx.val[0], src[3][0]);
    product1.val[0] = vmulq_n_f32(_mtx.val[0], src[4][0]);
    product1.val[1] = vmulq_n_f32(_mtx.val[0], src[5][0]);
    product1.val[2] = vmulq_n_f32(_mtx.val[0], src[6][0]);
    product0.val[0] = vmlaq_n_f32(product0.val[0], _mtx.val[1], src[0][1]);
    product0.val[1] = vmlaq_n_f32(product0.val[1], _mtx.val[1], src[1][1]);
    product0.val[2] = vmlaq_n_f32(product0.val[2], _mtx.val[1], src[2][1]);
    product0.val[3] = vmlaq_n_f32(product0.val[3], _mtx.val[1], src[3][1]);
    product1.val[0] = vmlaq_n_f32(product1.val[0], _mtx.val[1], src[4][1]);
    product1.val[1] = vmlaq_n_f32(product1.val[1], _mtx.val[1], src[5][1]);
    product1.val[2] = vmlaq_n_f32(product1.val[2], _mtx.val[1], src[6][1]);
    product0.val[0] = vmlaq_n_f32(product0.val[0], _mtx.val[2], src[0][2]);
    product0.val[1] = vmlaq_n_f32(product0.val[1], _mtx.val[2], src[1][2]);
    product0.val[2] = vmlaq_n_f32(product0.val[2], _mtx.val[2], src[2][2]);
    product0.val[3] = vmlaq_n_f32(product0.val[3], _mtx.val[2], src[3][2]);
    product1.val[0] = vmlaq_n_f32(product1.val[0], _mtx.val[2], src[4][2]);
    product1.val[1] = vmlaq_n_f32(product1.val[1], _mtx.val[2], src[5][2]);
    product1.val[2] = vmlaq_n_f32(product1.val[2], _mtx.val[2], src[6][2]);

    // Normalize
    float32x2_t product00 = {product0.val[0][0],product0.val[0][1]};
    float32x2_t product01 = {product0.val[0][2],product0.val[0][3]};
    float32x2_t product10 = {product0.val[1][0],product0.val[1][1]};
    float32x2_t product11 = {product0.val[1][2],product0.val[1][3]};
    float32x2_t product20 = {product0.val[2][0],product0.val[2][1]};
    float32x2_t product21 = {product0.val[2][2],product0.val[2][3]};
    float32x2_t product30 = {product0.val[3][0],product0.val[3][1]};
    float32x2_t product31 = {product0.val[3][2],product0.val[3][3]};
    float32x2_t product40 = {product1.val[0][0],product1.val[0][1]};
    float32x2_t product41 = {product1.val[0][2],product1.val[0][3]};
    float32x2_t product50 = {product1.val[1][0],product1.val[1][1]};
    float32x2_t product51 = {product1.val[1][2],product1.val[1][3]};
    float32x2_t product60 = {product1.val[2][0],product1.val[2][1]};
    float32x2_t product61 = {product1.val[2][2],product1.val[2][3]};

    float32x2_t temp00;
    float32x2_t temp01;
    float32x2_t temp02;
    float32x2_t temp03;
    float32x2_t temp04;
    float32x2_t temp05;
    float32x2_t temp06;

    temp00 = vmul_f32(product00, product00);
    temp01 = vmul_f32(product10, product10);
    temp02 = vmul_f32(product20, product20);
    temp03 = vmul_f32(product30, product30);
    temp04 = vmul_f32(product40, product40);
    temp05 = vmul_f32(product50, product50);
    temp06 = vmul_f32(product60, product60);
    temp00 = vpadd_f32(temp00, temp00);
    temp01 = vpadd_f32(temp01, temp01);
    temp02 = vpadd_f32(temp02, temp02);
    temp03 = vpadd_f32(temp03, temp03);
    temp04 = vpadd_f32(temp04, temp04);
    temp05 = vpadd_f32(temp05, temp05);
    temp06 = vpadd_f32(temp06, temp06);
    temp00 = vmla_f32(temp00, product01, product01);       // temp[0] is important
    temp01 = vmla_f32(temp01, product11, product11);       // temp[0] is important
    temp02 = vmla_f32(temp02, product21, product21);       // temp[0] is important
    temp03 = vmla_f32(temp03, product31, product31);       // temp[0] is important
    temp04 = vmla_f32(temp04, product41, product41);       // temp[0] is important
    temp05 = vmla_f32(temp05, product51, product51);       // temp[0] is important
    temp06 = vmla_f32(temp06, product61, product61);       // temp[0] is important

    float32x4_t temp0 = {temp00[0], temp01[0], temp02[0], temp03[0]};
    float32x4_t temp1 = {temp04[0], temp05[0], temp06[0], 0.0};

    float32x4_t recpSqrtEst0;
    float32x4_t recpSqrtEst1;
    float32x4_t recp0;
    float32x4_t recp1;
    float32x4_t prod0;
    float32x4_t prod1;
    
    recpSqrtEst0 = vrsqrteq_f32(temp0);
    recpSqrtEst1 = vrsqrteq_f32(temp1);
    prod0 =        vmulq_f32(recpSqrtEst0,temp0);
    prod1 =        vmulq_f32(recpSqrtEst1,temp1);
    recp0 =        vrsqrtsq_f32(prod0,recpSqrtEst0);
    recp1 =        vrsqrtsq_f32(prod1,recpSqrtEst1);
    recpSqrtEst0 = vmulq_f32(recpSqrtEst0,recp0);
    recpSqrtEst1 = vmulq_f32(recpSqrtEst1,recp1);
    prod0 =        vmulq_f32(recpSqrtEst0,temp0);
    prod1 =        vmulq_f32(recpSqrtEst1,temp1);
    recp0 =        vrsqrtsq_f32(prod0,recpSqrtEst0);
    recp1 =        vrsqrtsq_f32(prod1,recpSqrtEst1);
    recpSqrtEst0 = vmulq_f32(recpSqrtEst0,recp0);
    recpSqrtEst1 = vmulq_f32(recpSqrtEst1,recp1);

    product0.val[0] = vmulq_n_f32(product0.val[0], recpSqrtEst0[0]);
    product0.val[1] = vmulq_n_f32(product0.val[1], recpSqrtEst0[1]);
    product0.val[2] = vmulq_n_f32(product0.val[2], recpSqrtEst0[2]);
    product0.val[3] = vmulq_n_f32(product0.val[3], recpSqrtEst0[3]);
    product1.val[0] = vmulq_n_f32(product1.val[0], recpSqrtEst1[0]);
    product1.val[1] = vmulq_n_f32(product1.val[1], recpSqrtEst1[1]);
    product1.val[2] = vmulq_n_f32(product1.val[2], recpSqrtEst1[2]);

    // Store mtx
    dst[0][0] = product0.val[0][0];
    dst[0][1] = product0.val[0][1];
    dst[0][2] = product0.val[0][2];
    dst[1][0] = product0.val[1][0];
    dst[1][1] = product0.val[1][1];
    dst[1][2] = product0.val[1][2];
    dst[2][0] = product0.val[2][0];
    dst[2][1] = product0.val[2][1];
    dst[2][2] = product0.val[2][2];
    dst[3][0] = product0.val[3][0];
    dst[3][1] = product0.val[3][1];
    dst[3][2] = product0.val[3][2];
    dst[4][0] = product1.val[0][0];
    dst[4][1] = product1.val[0][1];
    dst[4][2] = product1.val[0][2];
    dst[5][0] = product1.val[1][0];
    dst[5][1] = product1.val[1][1];
    dst[5][2] = product1.val[1][2];
    dst[6][0] = product1.val[2][0];
    dst[6][1] = product1.val[2][1];
    dst[6][2] = product1.val[2][2];

}

void Normalize(float v[3])
{
    // Load vector
    float32x4_t product = {v[0], v[1], v[2], 0.0};

    // Normalize
    float32x2_t product0 = {product[0],product[1]};
    float32x2_t product1 = {product[2],product[3]};
    float32x2_t temp;

    temp = vmul_f32(product0, product0);
    temp = vpadd_f32(temp, temp);
    temp = vmla_f32(temp, product1, product1);       // temp[0] is important

    float32x2_t recpSqrtEst;
    float32x2_t recp;
    float32x2_t prod;
    
    recpSqrtEst = vrsqrte_f32(temp);
    prod =        vmul_f32(recpSqrtEst,temp);
    recp =        vrsqrts_f32(prod,recpSqrtEst);
    recpSqrtEst = vmul_f32(recpSqrtEst,recp);
    prod =        vmul_f32(recpSqrtEst,temp);
    recp =        vrsqrts_f32(prod,recpSqrtEst);
    recpSqrtEst = vmul_f32(recpSqrtEst,recp);

    product = vmulq_n_f32(product, recpSqrtEst[0]);

    // Store vector
    v[0] = product[0];
    v[1] = product[1];
    v[2] = product[2];
}

void InverseTransformVectorNormalizeN(float src[][3], float dst[][3], float mtx[4][4], u32 count)
{
    while (count >= 7) {
        InverseTransformVectorNormalize7((float (*)[3])src[count-7], (float (*)[3])dst[count-7], mtx);
        count -= 7;
    }
    while (count >= 4) {
        InverseTransformVectorNormalize4((float (*)[3])src[count-4], (float (*)[3])dst[count-4], mtx);
        count -= 4;
    }
    while (count >= 1) {
        InverseTransformVectorNormalize((float (*))src[count-1], (float (*))dst[count-1], mtx);
        count--;
    }

}

void CopyMatrix( float m0[4][4], float m1[4][4] )
{
    // load and store 16 floats
    vst4q_f32(m0[0],vld4q_f32(m1[0]));
}
