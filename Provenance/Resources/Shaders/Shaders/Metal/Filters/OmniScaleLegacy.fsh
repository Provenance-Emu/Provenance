STATIC float quickDistance(vec4 a, vec4 b)
{
    return abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z);
}

STATIC vec4 scale(sampler2D image, vec2 position, vec2 input_resolution, vec2 output_resolution)
{
    vec2 pixel = position * input_resolution - vec2(0.5, 0.5);

    vec4 q11 = texture(image, (floor(pixel) + 0.5) / input_resolution);
    vec4 q12 = texture(image, (vec2(floor(pixel.x), ceil(pixel.y)) + 0.5) / input_resolution);
    vec4 q21 = texture(image, (vec2(ceil(pixel.x), floor(pixel.y)) + 0.5) / input_resolution);
    vec4 q22 = texture(image, (ceil(pixel) + 0.5) / input_resolution);

    vec2 pos = fract(pixel);

    /* Special handling for diaonals */
    bool hasDownDiagonal = false;
    bool hasUpDiagonal = false;
    if (equal(q12, q21) && inequal(q11, q22)) hasUpDiagonal = true;
    else if (inequal(q12, q21) && equal(q11, q22)) hasDownDiagonal = true;
    else if (equal(q12, q21) && equal(q11, q22)) {
        if (equal(q11, q12)) return q11;
        int diagonalBias = 0;
        for (float y = -1.0; y < 3.0; y++) {
            for (float x = -1.0; x < 3.0; x++) {
                vec4 color = texture(image, (pixel + vec2(x, y)) / input_resolution);
                if (equal(color, q11)) diagonalBias++;
                if (equal(color, q12)) diagonalBias--;
            }
        }
        if (diagonalBias <= 0) {
            hasDownDiagonal = true;
        }
        if (diagonalBias >= 0) {
            hasUpDiagonal = true;
        }
    }

    if (hasUpDiagonal || hasDownDiagonal) {
        vec4 downDiagonalResult, upDiagonalResult;

        if (hasUpDiagonal) {
            float diagonalPos = pos.x + pos.y;

            if (diagonalPos < 0.5) {
                upDiagonalResult = q11;
            }
            else if (diagonalPos > 1.5) {
                upDiagonalResult = q22;
            }
            else {
                upDiagonalResult = q12;
            }
        }

        if (hasDownDiagonal) {
            float diagonalPos = 1.0 - pos.x + pos.y;

            if (diagonalPos < 0.5) {
                downDiagonalResult = q21;
            }
            else if (diagonalPos > 1.5) {
                downDiagonalResult = q12;
            }
            else {
                downDiagonalResult = q11;
            }
        }

        if (!hasUpDiagonal) return downDiagonalResult;
        if (!hasDownDiagonal) return upDiagonalResult;
        return mix(downDiagonalResult, upDiagonalResult, 0.5);
    }

    vec4 r1 = mix(q11, q21, fract(pos.x));
    vec4 r2 = mix(q12, q22, fract(pos.x));
    
    vec4 unqunatized = mix(r1, r2, fract(pos.y));

    float q11d = quickDistance(unqunatized, q11);
    float q21d = quickDistance(unqunatized, q21);
    float q12d = quickDistance(unqunatized, q12);
    float q22d = quickDistance(unqunatized, q22);

    float best = min(q11d,
                     min(q21d,
                         min(q12d,
                             q22d)));

    if (equal(q11d, best)) {
        return q11;
    }

    if (equal(q21d, best)) {
        return q21;
    }

    if (equal(q12d, best)) {
        return q12;
    }

    return q22;
}
