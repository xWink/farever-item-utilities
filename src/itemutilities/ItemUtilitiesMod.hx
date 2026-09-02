package itemutilities;

import haxe.Json;
import imgui.ImGui;
import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class ItemUtilitiesMod {
    static inline var CONFIG_PATH = "hlx/mods/item-utilities/config.json";
    static inline var CRAFTING_COMPONENT_TYPE = "CraftingComponent";

    static var enabled = new BoolRef(true);
    static var showDepositMaterials = new BoolRef(true);
    static var settingsOpen = new BoolRef(true);
    static var hasSeenMenu:Bool = false;

    static var hotkeyKey:Int = ImGuiKey.F9;
    static var hotkeyCtrl:Bool = false;
    static var hotkeyShift:Bool = false;
    static var hotkeyAlt:Bool = false;
    static var hotkeySuper:Bool = false;
    static var capturingHotkey:Bool = false;

    static var activeBankWindow:Dynamic;
    static var activeInventoryWindow:Dynamic;
    static var openInventoryWindows:Array<{ window:Dynamic, inventory:Dynamic }> = [];
    static var depositButton:Dynamic;
    static var sourceInventory:Dynamic;
    static var bankInventory:Dynamic;
    static var depositing:Bool = false;
    static var transferIndexes:Array<Int> = [];
    static var transferPosition:Int = 0;
    static var status:String = "";
    static var movedStacks:Int = 0;

    static var itemType:hl.Bytes;
    static var inventoryType:hl.Bytes;
    static var bankWindowType:hl.Bytes;
    static var arrayObjType:hl.Bytes;
    static var cursorType:hl.Bytes;
    static var systemType:hl.Bytes;
    static var propertiesType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var h2dObjectType:hl.Bytes;
    static var isTypeMember:hlx.runtime.ResolvedMember;
    static var equalsMember:hlx.runtime.ResolvedMember;
    static var isMaxStackMember:hlx.runtime.ResolvedMember;
    static var getSlotStackSizeMember:hlx.runtime.ResolvedMember;
    static var getNextFreeIndexMember:hlx.runtime.ResolvedMember;
    static var requestTransferMember:hlx.runtime.ResolvedMember;
    static var getMyHeroMember:hlx.runtime.ResolvedMember;
    static var arrayGetDynMember:hlx.runtime.ResolvedMember;
    static var setSystemCursorMember:hlx.runtime.ResolvedMember;
    static var buttonCursor:Dynamic;
    static var cursorErrorLogged:Bool = false;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;
    static var setTextTipMember:hlx.runtime.ResolvedMember;
    static var setVisibleMember:hlx.runtime.ResolvedMember;
    static var getChildIndexMember:hlx.runtime.ResolvedMember;
    static var addChildAtMember:hlx.runtime.ResolvedMember;

    static function main():Void {
        loadConfig();
        settingsOpen.set(!hasSeenMenu);
        ImGui.register(HlxRuntime.moduleName(), draw);
    }

    @:hlx.postfix(ui.win.BankWindow.init)
    static function afterBankInit(instance:Dynamic, result:Void):Void {
        activeBankWindow = instance;
        try bankInventory = HlxRuntime.resolveField(instance, "inventory") catch (_:Dynamic) {}
        depositButton = null;
        status = "";
        cancelDeposit();
        refreshInventories();
    }

    @:hlx.postfix(ui.win.InventoryWindow.init)
    static function afterInventoryInit(instance:Dynamic, result:Void):Void {
        try {
            var inventory:Dynamic = HlxRuntime.resolveField(instance, "inventory");
            if (inventory == null)
                return;

            var known = false;
            for (entry in openInventoryWindows) {
                if (entry.window == instance) {
                    entry.inventory = inventory;
                    known = true;
                    break;
                }
            }
            if (!known)
                openInventoryWindows.push({ window: instance, inventory: inventory });

            selectSourceInventory();
        } catch (_:Dynamic) {}
    }

    @:hlx.postfix(ui.win.TitleWindow.onRemove)
    static function afterTitleWindowRemove(instance:Dynamic, result:Void):Void {
        var kept:Array<{ window:Dynamic, inventory:Dynamic }> = [];
        for (entry in openInventoryWindows)
            if (entry.window != instance) kept.push(entry);
        openInventoryWindows = kept;

        if (instance == activeInventoryWindow) {
            activeInventoryWindow = null;
            sourceInventory = null;
        }
        if (instance == activeBankWindow) {
            cancelDeposit();
            activeBankWindow = null;
            depositButton = null;
            bankInventory = null;
        }
        selectSourceInventory();
    }

    static function draw():Void {
        if (!capturingHotkey && hotkeyPressed())
            settingsOpen.set(!settingsOpen.get());

        if (settingsOpen.get())
            drawSettings();

        if (activeBankWindow != null && enabled.get() && showDepositMaterials.get())
            drawBankHeaderButton();

    }

    static function drawSettings():Void {
        ImGui.setNextWindowBgAlpha(0.98);
        if (!ImGui.begin("Item Utilities Settings", settingsOpen)) {
            ImGui.end();
            return;
        }

        if (!hasSeenMenu) {
            hasSeenMenu = true;
            saveConfig();
        }

        var oldEnabled = enabled.get();
        ImGui.checkbox("Enable item utilities", enabled);
        if (enabled.get() != oldEnabled) {
            if (!enabled.get()) cancelDeposit();
            syncDepositButtonVisibility();
            saveConfig();
        }

        var oldDeposit = showDepositMaterials.get();
        ImGui.checkbox("Show Deposit Crafting Components button", showDepositMaterials);
        if (showDepositMaterials.get() != oldDeposit) {
            if (!showDepositMaterials.get()) cancelDeposit();
            syncDepositButtonVisibility();
            saveConfig();
        }

        ImGui.separator();
        ImGui.text("Open settings hotkey: " + hotkeyLabel());
        if (!capturingHotkey) {
            if (ImGui.button("Change hotkey"))
                capturingHotkey = true;
        } else {
            ImGui.text("Press a key combination...");
            ImGui.text("Hold Ctrl/Shift/Alt/Win, then press a key. Esc cancels.");
            captureNextHotkey();
        }

        ImGui.end();
    }

    static function drawBankHeaderButton():Void {
        var sortButton:Dynamic = null;
        try {
            var comp:Dynamic = HlxRuntime.resolveField(activeBankWindow, "comp");
            sortButton = comp == null ? null : HlxRuntime.resolveField(comp, "sortButton");
        } catch (_:Dynamic) {}
        if (sortButton == null)
            return;

        var x:Float;
        var y:Float;
        try {
            x = cast HlxRuntime.resolveField(sortButton, "absX");
            y = cast HlxRuntime.resolveField(sortButton, "absY");
        } catch (_:Dynamic) {
            return;
        }

        // Keep the utility in the Bank header without modifying Domkit's live
        // component tree (doing that after init can invalidate the whole UI).
        ImGui.setNextWindowPos(new ImVec2(x - 38, y));
        ImGui.setNextWindowBgAlpha(0);
        var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
            | ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoSavedSettings
            | ImGuiWindowFlags.NoFocusOnAppearing;
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, new ImVec2(0, 0));
        ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 5.0);
        ImGui.pushStyleColor(ImGuiCol.Button, new ImVec4(0.40, 0.37, 0.35, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, new ImVec4(0.48, 0.44, 0.41, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, new ImVec4(0.32, 0.29, 0.27, 1));
        ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.92, 0.86, 0.80, 1));
        if (!ImGui.begin("##item-utilities-bank-header", null, flags)) {
            ImGui.end();
            ImGui.popStyleColor(4);
            ImGui.popStyleVar(2);
            return;
        }

        if (ImGui.button("##deposit-materials", new ImVec2(32, 30)))
            if (!depositing) beginDeposit();
        drawDepositIcon();
        if (ImGui.isItemHovered()) {
            setGameButtonCursor();
            ImGui.setTooltip(" " + (status.length > 0 ? status : "Deposit Crafting Components") + " ");
        }

        ImGui.end();
        ImGui.popStyleColor(4);
        ImGui.popStyleVar(2);
    }

    static function drawDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var crystal = ImGui.colorConvertFloat4ToU32(new ImVec4(0.91, 0.70, 0.39, 1));
        var crystalShade = ImGui.colorConvertFloat4ToU32(new ImVec4(0.72, 0.48, 0.25, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // A small crafting crystal.
        ImGui.ImDrawList_AddQuadFilled(drawList,
            new ImVec2(min.x + 6, min.y + 10),
            new ImVec2(min.x + 11, min.y + 5),
            new ImVec2(min.x + 16, min.y + 10),
            new ImVec2(min.x + 11, min.y + 17), crystal);
        ImGui.ImDrawList_AddTriangleFilled(drawList,
            new ImVec2(min.x + 6, min.y + 10),
            new ImVec2(min.x + 11, min.y + 17),
            new ImVec2(min.x + 11, min.y + 10), crystalShade);

        // Down arrow and receiving tray communicate "deposit" at a glance.
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 21, min.y + 6),
            new ImVec2(min.x + 21, min.y + 16), mark, 2.0);
        ImGui.ImDrawList_AddTriangleFilled(drawList,
            new ImVec2(min.x + 17, min.y + 14),
            new ImVec2(min.x + 25, min.y + 14),
            new ImVec2(min.x + 21, min.y + 19), mark);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 8, min.y + 23),
            new ImVec2(min.x + 25, min.y + 23), mark, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 8, min.y + 19),
            new ImVec2(min.x + 8, min.y + 23), mark, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 25, min.y + 19),
            new ImVec2(min.x + 25, min.y + 23), mark, 2.0);
    }

    static function setGameButtonCursor():Void {
        try {
            if (cursorType == null)
                cursorType = HlxRuntime.resolveType("hxd.Cursor");
            if (systemType == null)
                systemType = HlxRuntime.resolveType("hxd.System");
            if (cursorType == null || systemType == null)
                return;
            if (buttonCursor == null)
                buttonCursor = HlxRuntime.constructEnum(cursorType, "Button", []);
            if (setSystemCursorMember == null)
                setSystemCursorMember = HlxRuntime.resolveStaticMember(systemType, "setCursor");
            if (buttonCursor != null && setSystemCursorMember != null)
                HlxRuntime.callResolved(setSystemCursorMember, [buttonCursor]);
        } catch (error:Dynamic) {
            if (!cursorErrorLogged) {
                cursorErrorLogged = true;
                trace("[ItemUtilities] button cursor failed: " + Std.string(error));
            }
        }
    }

    static function beginDeposit():Void {
        if (!refreshInventories() || !resolveMembers()) {
            status = "Inventory is not ready.";
            return;
        }

        transferIndexes = [];
        transferPosition = 0;
        movedStacks = 0;

        var content = getContent(sourceInventory);
        if (content == null) {
            status = "Inventory is not ready.";
            return;
        }

        for (index in 0...arrayLength(content)) {
            var stack:Dynamic = arrayGet(content, index);
            if (stack == null)
                continue;
            var item:Dynamic = HlxRuntime.resolveField(stack, "item");
            if (isCraftingComponent(item))
                transferIndexes.push(index);
        }

        if (transferIndexes.length == 0) {
            status = "No crafting components to deposit.";
            return;
        }

        depositing = true;
        status = "";
        transferNext();
    }

    static function transferNext():Void {
        if (!depositing || activeBankWindow == null) {
            cancelDeposit();
            return;
        }

        var content = getContent(sourceInventory);
        while (transferPosition < transferIndexes.length) {
            var sourceIndex = transferIndexes[transferPosition];
            var stack:Dynamic = content == null || sourceIndex >= arrayLength(content) ? null : arrayGet(content, sourceIndex);
            if (stack == null) {
                transferPosition++;
                continue;
            }

            var item:Dynamic = HlxRuntime.resolveField(stack, "item");
            if (!isCraftingComponent(item)) {
                transferPosition++;
                continue;
            }

            var destination = findDestination(item);
            if (destination.index < 0) {
                depositing = false;
                status = "Bank is full. Deposited " + movedStacks + " stack" + (movedStacks == 1 ? "." : "s.");
                return;
            }

            var count:Dynamic = destination.count;
            var callback = function(success:Bool):Void {
                if (!depositing)
                    return;
                if (!success) {
                    depositing = false;
                    status = "A material could not be deposited.";
                    return;
                }
                movedStacks++;

                // A partially filled bank stack may not consume the whole source
                // stack. Retry this source slot until it is empty, then advance.
                var current = getContent(sourceInventory);
                var remaining:Dynamic = current == null || sourceIndex >= arrayLength(current) ? null : arrayGet(current, sourceIndex);
                if (remaining == null)
                    transferPosition++;
                transferNext();
            };

            try {
                HlxRuntime.callResolved(requestTransferMember, [
                    sourceInventory,
                    sourceIndex,
                    bankInventory,
                    destination.index,
                    null,
                    count,
                    callback
                ]);
            } catch (_:Dynamic) {
                depositing = false;
                status = "A material could not be deposited.";
            }
            return;
        }

        depositing = false;
        status = "Deposited all crafting components.";
    }

    static function findDestination(item:Dynamic):{ index:Int, count:Dynamic } {
        var bankContent = getContent(bankInventory);
        if (bankContent != null) {
            for (index in 0...arrayLength(bankContent)) {
                var stack:Dynamic = arrayGet(bankContent, index);
                if (stack == null)
                    continue;
                var other:Dynamic = HlxRuntime.resolveField(stack, "item");
                if (other == null)
                    continue;
                var same:Dynamic = HlxRuntime.callResolved(equalsMember, [item, other]);
                if (same != true)
                    continue;
                var full:Dynamic = HlxRuntime.callResolved(isMaxStackMember, [bankInventory, index]);
                if (full == true)
                    continue;

                var capacity:Dynamic = HlxRuntime.callResolved(getSlotStackSizeMember, [bankInventory, index]);
                var current:Dynamic = HlxRuntime.resolveField(stack, "count");
                var space:Int = cast capacity - cast current;
                return { index: index, count: space };
            }
        }

        var free:Dynamic = HlxRuntime.callResolved(getNextFreeIndexMember, [bankInventory, item]);
        return { index: cast free, count: null };
    }

    static function isCraftingComponent(item:Dynamic):Bool {
        if (item == null || isTypeMember == null)
            return false;
        try {
            return HlxRuntime.callResolved(isTypeMember, [item, CRAFTING_COMPONENT_TYPE]) == true;
        } catch (_:Dynamic) {
            return false;
        }
    }

    static function refreshInventories():Bool {
        if (activeBankWindow == null)
            return false;
        try {
            if (bankInventory == null)
                bankInventory = HlxRuntime.resolveField(activeBankWindow, "inventory");
            selectSourceInventory();
            if (sourceInventory == null)
                sourceInventory = resolveHeroInventory();
        } catch (_:Dynamic) {
            return false;
        }
        return sourceInventory != null && bankInventory != null;
    }

    static function resolveHeroInventory():Dynamic {
        try {
            if (bankWindowType == null)
                bankWindowType = HlxRuntime.resolveType("ui.win.BankWindow");
            if (bankWindowType == null)
                return null;
            if (getMyHeroMember == null)
                getMyHeroMember = HlxRuntime.resolveMember(bankWindowType, "get_myHero");
            if (getMyHeroMember == null) {
                trace("[ItemUtilities] get_myHero could not be resolved");
                return null;
            }

            var hero:Dynamic = HlxRuntime.callResolved(getMyHeroMember, [activeBankWindow]);
            var loadout:Dynamic = hero == null ? null : HlxRuntime.resolveField(hero, "loadout");
            var inventory:Dynamic = loadout == null ? null : HlxRuntime.resolveField(loadout, "inventory");
            return inventory;
        } catch (error:Dynamic) {
            trace("[ItemUtilities] hero fallback failed: " + Std.string(error));
            return null;
        }
    }

    static function selectSourceInventory():Void {
        sourceInventory = null;
        activeInventoryWindow = null;
        for (entry in openInventoryWindows) {
            if (entry.window == activeBankWindow || entry.inventory == bankInventory)
                continue;
            activeInventoryWindow = entry.window;
            sourceInventory = entry.inventory;
            return;
        }
    }

    static function getContent(inventory:Dynamic):Dynamic {
        if (inventory == null)
            return null;
        try {
            // `content` is the authoritative replicated array, but Farever can
            // leave it null on the client while exposing the materialized slot
            // array through `stacks`.
            var content:Dynamic = HlxRuntime.resolveField(inventory, "content");
            if (content != null)
                return content;
            var stacks:Dynamic = HlxRuntime.resolveField(inventory, "stacks");
            if (stacks != null)
                return stacks;
        } catch (error:Dynamic) {
            trace("[ItemUtilities] inventory slot access failed: " + Std.string(error));
        }
        return null;
    }

    static function arrayLength(array:Dynamic):Int {
        if (array == null)
            return 0;
        try return cast HlxRuntime.resolveField(array, "length") catch (_:Dynamic) return 0;
    }

    static function arrayGet(array:Dynamic, index:Int):Dynamic {
        if (array == null)
            return null;
        try {
            if (arrayObjType == null)
                arrayObjType = HlxRuntime.resolveType("hl.types.ArrayObj");
            if (arrayObjType == null)
                return null;
            if (arrayGetDynMember == null)
                arrayGetDynMember = HlxRuntime.resolveMember(arrayObjType, "getDyn");
            if (arrayGetDynMember == null)
                return null;
            return HlxRuntime.callResolved(arrayGetDynMember, [array, index]);
        } catch (error:Dynamic) {
            trace("[ItemUtilities] typed array read failed at " + index + ": " + Std.string(error));
            return null;
        }
    }

    static function resolveMembers():Bool {
        if (itemType == null) itemType = HlxRuntime.resolveType("st.Item");
        if (inventoryType == null) inventoryType = HlxRuntime.resolveType("st.Inventory");
        if (itemType == null || inventoryType == null)
            return false;

        if (isTypeMember == null) isTypeMember = HlxRuntime.resolveMember(itemType, "isType");
        if (equalsMember == null) equalsMember = HlxRuntime.resolveMember(itemType, "equals");
        if (isMaxStackMember == null) isMaxStackMember = HlxRuntime.resolveMember(inventoryType, "isMaxStack");
        if (getSlotStackSizeMember == null) getSlotStackSizeMember = HlxRuntime.resolveMember(inventoryType, "getSlotStackSize");
        if (getNextFreeIndexMember == null) getNextFreeIndexMember = HlxRuntime.resolveMember(inventoryType, "getNextFreeIndex");
        if (requestTransferMember == null) requestTransferMember = HlxRuntime.resolveMember(inventoryType, "requestTransfer");

        return isTypeMember != null && equalsMember != null
            && isMaxStackMember != null && getSlotStackSizeMember != null
            && getNextFreeIndexMember != null && requestTransferMember != null;
    }

    static function installDepositButton():Void {
        try {
            if (!resolveUiMembers())
                return;

            var inventoryComp:Dynamic = HlxRuntime.resolveField(activeBankWindow, "comp");
            var sortButton:Dynamic = inventoryComp == null ? null : HlxRuntime.resolveField(inventoryComp, "sortButton");
            var sortProperties:Dynamic = sortButton == null ? null : HlxRuntime.resolveField(sortButton, "dom");
            if (sortProperties == null)
                return;

            var parentProperties:Dynamic = HlxRuntime.callResolved(getParentPropertiesMember, [sortProperties]);
            if (parentProperties == null)
                return;

            var createdProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button-icon",
                parentProperties,
                ["Item_Transfer"],
                { id: "depositCraftingMaterials" }
            ]);
            if (createdProperties == null)
                return;

            depositButton = HlxRuntime.resolveField(createdProperties, "obj");
            if (depositButton == null)
                return;

            HlxRuntime.callResolved(setOnClickMember, [depositButton, beginDeposit]);
            HlxRuntime.callResolved(setTextTipMember, [depositButton, "Deposit Crafting Components"]);

            // Domkit appends new components. Move ours immediately after Sort so
            // it behaves like a native part of the inventory header.
            var parentObject:Dynamic = HlxRuntime.resolveField(parentProperties, "obj");
            if (parentObject != null) {
                var sortIndex:Dynamic = HlxRuntime.callResolved(getChildIndexMember, [parentObject, sortButton]);
                if (sortIndex != null && cast sortIndex >= 0)
                    HlxRuntime.callResolved(addChildAtMember, [parentObject, depositButton, cast sortIndex + 1]);
            }

            syncDepositButtonVisibility();
        } catch (_:Dynamic) {
            depositButton = null;
        }
    }

    static function syncDepositButtonVisibility():Void {
        if (depositButton == null || !resolveUiMembers())
            return;
        try HlxRuntime.callResolved(setVisibleMember, [depositButton, enabled.get() && showDepositMaterials.get()]) catch (_:Dynamic) {}
    }

    static function resolveUiMembers():Bool {
        if (propertiesType == null) propertiesType = HlxRuntime.resolveType("domkit.Properties");
        if (uiElementType == null) uiElementType = HlxRuntime.resolveType("ui.UIElement");
        if (h2dObjectType == null) h2dObjectType = HlxRuntime.resolveType("h2d.Object");
        if (propertiesType == null || uiElementType == null || h2dObjectType == null)
            return false;

        if (createNewMember == null) createNewMember = HlxRuntime.resolveStaticMember(propertiesType, "createNew");
        if (getParentPropertiesMember == null) getParentPropertiesMember = HlxRuntime.resolveMember(propertiesType, "get_parent");
        if (setOnClickMember == null) setOnClickMember = HlxRuntime.resolveMember(uiElementType, "set_onClick");
        if (setTextTipMember == null) setTextTipMember = HlxRuntime.resolveMember(uiElementType, "set_textTip");
        if (setVisibleMember == null) setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");
        if (getChildIndexMember == null) getChildIndexMember = HlxRuntime.resolveMember(h2dObjectType, "getChildIndex");
        if (addChildAtMember == null) addChildAtMember = HlxRuntime.resolveMember(h2dObjectType, "addChildAt");

        return createNewMember != null && getParentPropertiesMember != null
            && setOnClickMember != null && setTextTipMember != null && setVisibleMember != null
            && getChildIndexMember != null && addChildAtMember != null;
    }

    static function cancelDeposit():Void {
        depositing = false;
        transferIndexes = [];
        transferPosition = 0;
    }

    static function hotkeyPressed():Bool {
        if (!ImGui.isKeyPressed(hotkeyKey, false)) return false;
        return modifierDown(ImGuiKey.LeftCtrl, ImGuiKey.RightCtrl) == hotkeyCtrl
            && modifierDown(ImGuiKey.LeftShift, ImGuiKey.RightShift) == hotkeyShift
            && modifierDown(ImGuiKey.LeftAlt, ImGuiKey.RightAlt) == hotkeyAlt
            && modifierDown(ImGuiKey.LeftSuper, ImGuiKey.RightSuper) == hotkeySuper;
    }

    static function captureNextHotkey():Void {
        if (ImGui.isKeyPressed(ImGuiKey.Escape, false)) {
            capturingHotkey = false;
            return;
        }
        for (key in 512...632) {
            if (isModifierKey(key) || key == ImGuiKey.Escape) continue;
            if (ImGui.isKeyPressed(key, false)) {
                hotkeyKey = key;
                hotkeyCtrl = modifierDown(ImGuiKey.LeftCtrl, ImGuiKey.RightCtrl);
                hotkeyShift = modifierDown(ImGuiKey.LeftShift, ImGuiKey.RightShift);
                hotkeyAlt = modifierDown(ImGuiKey.LeftAlt, ImGuiKey.RightAlt);
                hotkeySuper = modifierDown(ImGuiKey.LeftSuper, ImGuiKey.RightSuper);
                capturingHotkey = false;
                saveConfig();
                return;
            }
        }
    }

    static inline function modifierDown(left:Int, right:Int):Bool
        return ImGui.isKeyDown(left) || ImGui.isKeyDown(right);

    static inline function isModifierKey(key:Int):Bool
        return key >= ImGuiKey.LeftCtrl && key <= ImGuiKey.RightSuper;

    static function hotkeyLabel():String {
        var parts = new Array<String>();
        if (hotkeyCtrl) parts.push("Ctrl");
        if (hotkeyShift) parts.push("Shift");
        if (hotkeyAlt) parts.push("Alt");
        if (hotkeySuper) parts.push("Win");
        parts.push(keyLabel(hotkeyKey));
        return parts.join(" + ");
    }

    static function keyLabel(key:Int):String {
        if (key >= ImGuiKey._0 && key <= ImGuiKey._9) return String.fromCharCode(48 + key - ImGuiKey._0);
        if (key >= ImGuiKey.A && key <= ImGuiKey.Z) return String.fromCharCode(65 + key - ImGuiKey.A);
        if (key >= ImGuiKey.F1 && key <= ImGuiKey.F24) return "F" + (key - ImGuiKey.F1 + 1);
        return switch (key) {
            case ImGuiKey.Tab: "Tab";
            case ImGuiKey.Space: "Space";
            case ImGuiKey.Enter: "Enter";
            case ImGuiKey.Insert: "Insert";
            case ImGuiKey.Delete: "Delete";
            case ImGuiKey.Home: "Home";
            case ImGuiKey.End: "End";
            case ImGuiKey.PageUp: "Page Up";
            case ImGuiKey.PageDown: "Page Down";
            case ImGuiKey.LeftArrow: "Left";
            case ImGuiKey.RightArrow: "Right";
            case ImGuiKey.UpArrow: "Up";
            case ImGuiKey.DownArrow: "Down";
            default: "Key " + key;
        };
    }

    static function loadConfig():Void {
        try {
            if (!FileSystem.exists(CONFIG_PATH)) return;
            var data:Dynamic = Json.parse(File.getContent(CONFIG_PATH));
            if (Reflect.hasField(data, "enabled")) enabled.set(Reflect.field(data, "enabled"));
            if (Reflect.hasField(data, "showDepositMaterials")) showDepositMaterials.set(Reflect.field(data, "showDepositMaterials"));
            if (Reflect.hasField(data, "hotkeyKey")) hotkeyKey = cast Reflect.field(data, "hotkeyKey");
            if (Reflect.hasField(data, "hotkeyCtrl")) hotkeyCtrl = Reflect.field(data, "hotkeyCtrl");
            if (Reflect.hasField(data, "hotkeyShift")) hotkeyShift = Reflect.field(data, "hotkeyShift");
            if (Reflect.hasField(data, "hotkeyAlt")) hotkeyAlt = Reflect.field(data, "hotkeyAlt");
            if (Reflect.hasField(data, "hotkeySuper")) hotkeySuper = Reflect.field(data, "hotkeySuper");
            if (Reflect.hasField(data, "hasSeenMenu")) hasSeenMenu = Reflect.field(data, "hasSeenMenu");
            else hasSeenMenu = true;
        } catch (_:Dynamic) {}
    }

    static function saveConfig():Void {
        try File.saveContent(CONFIG_PATH, Json.stringify({
            enabled: enabled.get(),
            showDepositMaterials: showDepositMaterials.get(),
            hotkeyKey: hotkeyKey,
            hotkeyCtrl: hotkeyCtrl,
            hotkeyShift: hotkeyShift,
            hotkeyAlt: hotkeyAlt,
            hotkeySuper: hotkeySuper,
            hasSeenMenu: hasSeenMenu
        }, null, "  ")) catch (_:Dynamic) {}
    }
}
