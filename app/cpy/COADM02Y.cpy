000100******************************************************************00010000
000200* CardDemo - Admin Menu Options                                   00020000
000300******************************************************************00030000
000400* Copyright Amazon.com, Inc. or its affiliates.                   00040000
000500* All Rights Reserved.                                            00050000
000600*                                                                 00060000
000700* Licensed under the Apache License, Version 2.0 (the "License"). 00070000
000800* You may not use this file except in compliance with the License.00080000
000900* You may obtain a copy of the License at                         00090000
001000*                                                                 00100000
001100*    http://www.apache.org/licenses/LICENSE-2.0                   00110000
001200*                                                                 00120000
001300* Unless required by applicable law or agreed to in writing,      00130000
001400* software distributed under the License is distributed on an     00140000
001500* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    00150000
001600* either express or implied. See the License for the specific     00160000
001700* language governing permissions and limitations under the License00170000
001800******************************************************************00180000
001900 01 CARDDEMO-ADMIN-MENU-OPTIONS.
         05 CDEMO-ADMIN-OPT-COUNT           PIC 9(02) VALUE 2.
         05 CDEMO-ADMIN-OPTIONS-DATA.

           10 FILLER                        PIC 9(02) VALUE 1.
           10 FILLER                        PIC X(35) VALUE
               'User Update (Security)             '.
           10 FILLER                        PIC X(08) VALUE 'COUSR02C'.

           10 FILLER                        PIC 9(02) VALUE 2.
           10 FILLER                        PIC X(35) VALUE
               'User Delete (Security)             '.
           10 FILLER                        PIC X(08) VALUE 'COUSR03C'.

         05 CDEMO-ADMIN-OPTIONS REDEFINES CDEMO-ADMIN-OPTIONS-DATA.
           10 CDEMO-ADMIN-OPT OCCURS 2 TIMES.
             15 CDEMO-ADMIN-OPT-NUM           PIC 9(02).
             15 CDEMO-ADMIN-OPT-NAME          PIC X(35).
             15 CDEMO-ADMIN-OPT-PGMNAME       PIC X(08).
005600*                                                                 00560000
005700* Ver: CardDemo_v2.0-16-gbdcb6ea-226 Date: 2024-01-21 17:49:00 CST
005800*                                                                 00580000
