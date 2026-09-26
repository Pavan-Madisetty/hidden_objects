import '../../models/world_def.dart';

/// Loose object in plain sight (cell 'fN') or partly covered ('bX').
ItemDef it(String id, String emoji, String name, String cell) =>
    ItemDef(id, emoji, name, cell: cell);

/// Object hidden inside the prop [propId].
ItemDef hid(String id, String emoji, String name, String propId) =>
    ItemDef(id, emoji, name, hiddenIn: propId, size: 70);

// Shared role ids (see WorldDef) --------------------------------------------
const String pCurtain = 'curtain'; // slot A
const String pCupboard = 'cupboard'; // slot B - lockable, holds the "light"
const String pDecor = 'decor'; // slot C - big scenery
const String pBox = 'box'; // slot D - drawer / toybox
const String pNook = 'nook'; // slot E - book or movable object
const String pPlant = 'plant'; // slot F
const String pLamp = 'lamp'; // slot G
const String pClock = 'clock'; // slot H
const String pDark = 'dark'; // dark area, lit by the "light"
