/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* sh7095_opdefs.inc:
**  Copyright (C) 2015-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#define OP_ILLEGAL                              case 0x00: /* (slot illegal) */
#define OP_MOV_IMM_REG                          case 0x01:case 0x81:
#define OP_MOV_W_PCREL_REG                      case 0x02:case 0x82:
#define OP_MOV_L_PCREL_REG                      case 0x03:case 0x83:
#define OP_MOV_REG_REG                          case 0x04:case 0x84:
#define OP_MOV_B_REG_REGINDIR                   case 0x05:case 0x85:
#define OP_MOV_W_REG_REGINDIR                   case 0x06:case 0x86:
#define OP_MOV_L_REG_REGINDIR                   case 0x07:case 0x87:
#define OP_MOV_B_REGINDIR_REG                   case 0x08:case 0x88:
#define OP_MOV_W_REGINDIR_REG                   case 0x09:case 0x89:
#define OP_MOV_L_REGINDIR_REG                   case 0x0a:case 0x8a:
#define OP_MOV_B_REG_REGINDIRPD                 case 0x0b:case 0x8b:
#define OP_MOV_W_REG_REGINDIRPD                 case 0x0c:case 0x8c:
#define OP_MOV_L_REG_REGINDIRPD                 case 0x0d:case 0x8d:
#define OP_MOV_B_REGINDIRPI_REG                 case 0x0e:case 0x8e:
#define OP_MOV_W_REGINDIRPI_REG                 case 0x0f:case 0x8f:
#define OP_MOV_L_REGINDIRPI_REG                 case 0x10:case 0x90:
#define OP_MOV_B_REG0_REGINDIRDISP              case 0x11:case 0x91:
#define OP_MOV_W_REG0_REGINDIRDISP              case 0x12:case 0x92:
#define OP_MOV_L_REG_REGINDIRDISP               case 0x13:case 0x93:
#define OP_MOV_B_REGINDIRDISP_REG0              case 0x14:case 0x94:
#define OP_MOV_W_REGINDIRDISP_REG0              case 0x15:case 0x95:
#define OP_MOV_L_REGINDIRDISP_REG               case 0x16:case 0x96:
#define OP_MOV_B_REG_IDXREGINDIR                case 0x17:case 0x97:
#define OP_MOV_W_REG_IDXREGINDIR                case 0x18:case 0x98:
#define OP_MOV_L_REG_IDXREGINDIR                case 0x19:case 0x99:
#define OP_MOV_B_IDXREGINDIR_REG                case 0x1a:case 0x9a:
#define OP_MOV_W_IDXREGINDIR_REG                case 0x1b:case 0x9b:
#define OP_MOV_L_IDXREGINDIR_REG                case 0x1c:case 0x9c:
#define OP_MOV_B_REG0_GBRINDIRDISP              case 0x1d:case 0x9d:
#define OP_MOV_W_REG0_GBRINDIRDISP              case 0x1e:case 0x9e:
#define OP_MOV_L_REG0_GBRINDIRDISP              case 0x1f:case 0x9f:
#define OP_MOV_B_GBRINDIRDISP_REG0              case 0x20:case 0xa0:
#define OP_MOV_W_GBRINDIRDISP_REG0              case 0x21:case 0xa1:
#define OP_MOV_L_GBRINDIRDISP_REG0              case 0x22:case 0xa2:
#define OP_MOVA_PCREL_REG0                      case 0x23:case 0xa3:
#define OP_MOVT_REG                             case 0x24:case 0xa4:
#define OP_SWAP_B_REG_REG                       case 0x25:case 0xa5:
#define OP_SWAP_W_REG_REG                       case 0x26:case 0xa6:
#define OP_XTRCT_REG_REG                        case 0x27:case 0xa7:
#define OP_ADD_REG_REG                          case 0x28:case 0xa8:
#define OP_ADD_IMM_REG                          case 0x29:case 0xa9:
#define OP_ADDC_REG_REG                         case 0x2a:case 0xaa:
#define OP_ADDV_REG_REG                         case 0x2b:case 0xab:
#define OP_CMP_EQ_IMM_REG0                      case 0x2c:case 0xac:
#define OP_CMP_EQ_REG_REG                       case 0x2d:case 0xad:
#define OP_CMP_HS_REG_REG                       case 0x2e:case 0xae:
#define OP_CMP_GE_REG_REG                       case 0x2f:case 0xaf:
#define OP_CMP_HI_REG_REG                       case 0x30:case 0xb0:
#define OP_CMP_GT_REG_REG                       case 0x31:case 0xb1:
#define OP_CMP_PZ_REG                           case 0x32:case 0xb2:
#define OP_CMP_PL_REG                           case 0x33:case 0xb3:
#define OP_CMP_STR_REG_REG                      case 0x34:case 0xb4:
#define OP_DIV1_REG_REG                         case 0x35:case 0xb5:
#define OP_DIV0S_REG_REG                        case 0x36:case 0xb6:
#define OP_DIV0U                                case 0x37:case 0xb7:
#define OP_DMULS_L_REG_REG                      case 0x38:case 0xb8:
#define OP_DMULU_L_REG_REG                      case 0x39:case 0xb9:
#define OP_DT                                   case 0x3a:case 0xba:
#define OP_EXTS_B_REG_REG                       case 0x3b:case 0xbb:
#define OP_EXTS_W_REG_REG                       case 0x3c:case 0xbc:
#define OP_EXTU_B_REG_REG                       case 0x3d:case 0xbd:
#define OP_EXTU_W_REG_REG                       case 0x3e:case 0xbe:
#define OP_MAC_L                                case 0x3f:case 0xbf:
#define OP_MAC_W                                case 0x40:case 0xc0:
#define OP_MUL_L_REG_REG                        case 0x41:case 0xc1:
#define OP_MULS_W_REG_REG                       case 0x42:case 0xc2:
#define OP_MULU_W_REG_REG                       case 0x43:case 0xc3:
#define OP_NEG_REG_REG                          case 0x44:case 0xc4:
#define OP_NEGC_REG_REG                         case 0x45:case 0xc5:
#define OP_SUB_REG_REG                          case 0x46:case 0xc6:
#define OP_SUBC_REG_REG                         case 0x47:case 0xc7:
#define OP_SUBV_REG_REG                         case 0x48:case 0xc8:
#define OP_AND_REG_REG                          case 0x49:case 0xc9:
#define OP_AND_IMM_REG0                         case 0x4a:case 0xca:
#define OP_AND_B_IMM_IDXGBRINDIR                case 0x4b:case 0xcb:
#define OP_NOT_REG_REG                          case 0x4c:case 0xcc:
#define OP_OR_REG_REG                           case 0x4d:case 0xcd:
#define OP_OR_IMM_REG0                          case 0x4e:case 0xce:
#define OP_OR_B_IMM_IDXGBRINDIR                 case 0x4f:case 0xcf:
#define OP_TAS_B_REGINDIR                       case 0x50:case 0xd0:
#define OP_TST_REG_REG                          case 0x51:case 0xd1:
#define OP_TST_IMM_REG0                         case 0x52:case 0xd2:
#define OP_TST_B_IMM_IDXGBRINDIR                case 0x53:case 0xd3:
#define OP_XOR_REG_REG                          case 0x54:case 0xd4:
#define OP_XOR_IMM_REG0                         case 0x55:case 0xd5:
#define OP_XOR_B_IMM_IDXGBRINDIR                case 0x56:case 0xd6:
#define OP_ROTL_REG                             case 0x57:case 0xd7:
#define OP_ROTR_REG                             case 0x58:case 0xd8:
#define OP_ROTCL_REG                            case 0x59:case 0xd9:
#define OP_ROTCR_REG                            case 0x5a:case 0xda:
#define OP_SHAR_REG                             case 0x5b:case 0xdb:
#define OP_SHLL_REG                             case 0x5c:case 0xdc:
#define OP_SHLR_REG                             case 0x5d:case 0xdd:
#define OP_SHLL2_REG                            case 0x5e:case 0xde:
#define OP_SHLR2_REG                            case 0x5f:case 0xdf:
#define OP_SHLL8_REG                            case 0x60:case 0xe0:
#define OP_SHLR8_REG                            case 0x61:case 0xe1:
#define OP_SHLL16_REG                           case 0x62:case 0xe2:
#define OP_SHLR16_REG                           case 0x63:case 0xe3:
#define OP_BF                                   case 0x64: /* (slot illegal) */
#define OP_BF_S                                 case 0x65: /* (slot illegal) */
#define OP_BT                                   case 0x66: /* (slot illegal) */
#define OP_BT_S                                 case 0x67: /* (slot illegal) */
#define OP_BRA                                  case 0x68: /* (slot illegal) */
#define OP_BRAF_REG                             case 0x69: /* (slot illegal) */
#define OP_BSR                                  case 0x6a: /* (slot illegal) */
#define OP_BSRF_REG                             case 0x6b: /* (slot illegal) */
#define OP_JMP_REGINDIR                         case 0x6c: /* (slot illegal) */
#define OP_JSR_REGINDIR                         case 0x6d: /* (slot illegal) */
#define OP_RTS                                  case 0x6e: /* (slot illegal) */
#define OP_CLRT                                 case 0x6f:case 0xef:
#define OP_CLRMAC                               case 0x70:case 0xf0:
#define OP_LDC                                  case 0x71:case 0xf1:
#define OP_LDC_L                                case 0x72:case 0xf2:
#define OP_LDS                                  case 0x73:case 0xf3:
#define OP_LDS_L                                case 0x74:case 0xf4:
#define OP_NOP                                  case 0x75:case 0xf5:
#define OP_RTE                                  case 0x76: /* (slot illegal) */
#define OP_SETT                                 case 0x77:case 0xf7:
#define OP_SLEEP                                case 0x78:case 0xf8:
#define OP_STC                                  case 0x79:case 0xf9:
#define OP_STC_L                                case 0x7a:case 0xfa:
#define OP_STS                                  case 0x7b:case 0xfb:
#define OP_STS_L                                case 0x7c:case 0xfc:
#define OP_TRAPA                                case 0x7d: /* (slot illegal) */

#define OP_SLOT_ILLEGAL                         case 0x80:case 0xe4:case 0xe5:case 0xe6:case 0xe7:case 0xe8:case 0xe9:case 0xea:case 0xeb:case 0xec:case 0xed:case 0xee:case 0xf6:case 0xfd:

//
// Pseudo-instructions:
//
#define OP_PSEUDO_STANDBY                       case 0x7e:
#define OP_PSEUDO_DMABURST			case 0xfe:
#define OP_PSEUDO_EPENDING                      case 0x7f: case 0xff:

