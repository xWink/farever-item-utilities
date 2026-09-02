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
import hlx.runtime.HlxPrefixControl;
import hlx.runtime.HlxPrefixResult;

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
    static var setSystemCursorFn:Dynamic;
    static var buttonCursor:Dynamic;
    static var cursorResolutionAttempted:Bool = false;
    static var cursorErrorLogged:Bool = false;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;
    static var setTextTipMember:hlx.runtime.ResolvedMember;
    static var setVisibleMember:hlx.runtime.ResolvedMember;
    static var getChildIndexMember:hlx.runtime.ResolvedMember;
    static var addChildAtMember:hlx.runtime.ResolvedMember;
    static var inventoryComps:Array<Dynamic> = [];
    static var playerInventoryComp:Dynamic;
    static var latestSlots:Array<Dynamic> = [];
    static var lockEditMode:Bool = false;
    static var lockRecords:Array<Dynamic> = [];
    static var previousItems:Map<String, Dynamic>;
    static var lockStateInitialized:Bool = false;
    static var activeCharacterKey:String;
    static var activeHero:Dynamic;
    static var playerControllerType:hl.Bytes;
    static var getControlTargetMember:hlx.runtime.ResolvedMember;
    static var inventorySlotType:hl.Bytes;
    static var setSlotLockedMember:hlx.runtime.ResolvedMember;
    static var lockErrors:Map<String, Bool> = new Map();
    static inline var MISSING_LOCK_SCAN_LIMIT = 90;

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

    @:hlx.postfix(ui.win.InventoryComp.init)
    static function afterLockInventoryCompInit(instance:Dynamic, result:Void):Void {
        var inventory:Dynamic = null;
        try inventory = HlxRuntime.resolveField(instance, "inventory") catch (_:Dynamic) {}
        var replaced = false;
        if (inventory != null) {
            for (index in 0...inventoryComps.length) {
                try {
                    if (HlxRuntime.resolveField(inventoryComps[index], "inventory") == inventory) {
                        inventoryComps[index] = instance;
                        replaced = true;
                        break;
                    }
                } catch (_:Dynamic) {}
            }
        }
        if (!replaced && inventoryComps.indexOf(instance) < 0)
            inventoryComps.push(instance);
        if (sourceInventory == null && activeBankWindow == null) {
            sourceInventory = inventory;
        }
        selectPlayerInventoryComp();
    }

    @:hlx.postfix(client.PlayerController.updateInputs)
    static function afterPlayerInputs(instance:Dynamic, dt:Float, result:Void):Void {
        try {
            if (playerControllerType == null)
                playerControllerType = HlxRuntime.resolveType("client.PlayerController");
            if (playerControllerType == null)
                return;
            if (getControlTargetMember == null)
                getControlTargetMember = HlxRuntime.resolveMember(playerControllerType, "getControlTarget");
            if (getControlTargetMember == null)
                return;
            var target:Dynamic = HlxRuntime.callResolved(getControlTargetMember, [instance]);
            if (target != null && fieldOrNull(target, "loadout") != null)
                activeHero = target;
        } catch (error:Dynamic) logLockError("hero capture", error);
    }

    @:hlx.postfix(ui.win.InventorySlot.init)
    static function afterLockSlotInit(instance:Dynamic, result:Void):Void {
        try {
            var inventory:Dynamic = HlxRuntime.resolveField(instance, "inventory");
            var index:Int = cast HlxRuntime.resolveField(instance, "index");
            if (inventory == null || index < 0) return;
            for (entry in latestSlots) {
                if (entry.inventory == inventory && entry.index == index) {
                    entry.slot = instance;
                    entry.modLocked = false;
                    applyLockEntry(entry);
                    return;
                }
            }
            var entry:Dynamic = { inventory: inventory, index: index, slot: instance, modLocked: false };
            latestSlots.push(entry);
            applyLockEntry(entry);
        } catch (error:Dynamic) logLockError("slot registration", error);
    }

    // Farever evaluates InventorySlot.defaultTransferAction/defaultEquipAction
    // while merely hovering an item. Lock editing therefore belongs on the
    // actual primary-click dispatcher, not either of those action selectors.
    @:hlx.prefix(ui.UIElement.click)
    static function lockEditPrimaryClick(instance:Dynamic):HlxPrefixControl {
        if (!enabled.get() || !lockEditMode)
            return Continue;
        var slot = findInventorySlotForElement(instance);
        return slot != null && handleLockEditClick(slot) ? Skip : Continue;
    }

    // A world discard is represented as a default transfer with no destination.
    // Keep ordinary inventory/bank/equipment transfers available for locked
    // items, but refuse the destination-less discard action.
    @:hlx.prefix(ui.win.InventorySlot.defaultTransferAction)
    static function protectLockedDefaultTransfer(instance:Dynamic, destination:Dynamic):HlxPrefixControl
        return destination == null && isLockedInventorySlot(instance) ? Skip : Continue;

    @:hlx.prefix(st.Loadout.canSellItem)
    static function protectLockedSale(instance:Dynamic, item:Dynamic):HlxPrefixResult<Bool>
        return isRuntimeLocked(item) ? SkipWith(false) : Continue;

    @:hlx.prefix(st.Loadout.canCompleteItem)
    static function protectLockedRecycler(instance:Dynamic, item:Dynamic):HlxPrefixResult<Bool>
        return isRuntimeLocked(item) ? SkipWith(false) : Continue;

    @:hlx.prefix(st.Inventory.canRequestDropIndex)
    static function protectLockedDrop(instance:Dynamic, index:Int, count:Bool,
        force:hl.Ref<Bool>, unknown:Null<Int>):HlxPrefixResult<Bool> {
        try {
            var stack = arrayGet(getContent(instance), index);
            var item:Dynamic = stack == null ? null : HlxRuntime.resolveField(stack, "item");
            return isRuntimeLocked(item) ? SkipWith(false) : Continue;
        } catch (error:Dynamic) {
            logLockError("discard guard", error);
            return Continue;
        }
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

        if (enabled.get())
            drawLockEditButton();

        if (enabled.get())
            reconcileLockState();

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
            if (!enabled.get()) {
                cancelDeposit();
                lockEditMode = false;
                clearModLockBadges();
            }
            resetLockValidation();
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
            ImGui.setTooltip("Deposit crafting components");
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
            if (!cursorResolutionAttempted) {
                cursorResolutionAttempted = true;
                setSystemCursorFn = HlxRuntime.resolveStaticField(systemType, "setCursor");
            }
            if (buttonCursor != null && setSystemCursorFn != null)
                Reflect.callMethod(null, setSystemCursorFn, [buttonCursor]);
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
            var hero = resolveHero();
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

    static function selectPlayerInventoryComp():Void {
        playerInventoryComp = null;
        if (sourceInventory == null)
            sourceInventory = resolveHeroInventory();
        for (comp in inventoryComps) {
            try {
                if (HlxRuntime.resolveField(comp, "inventory") == sourceInventory) {
                    playerInventoryComp = comp;
                    return;
                }
            } catch (_:Dynamic) {}
        }
    }

    static function drawLockEditButton():Void {
        selectPlayerInventoryComp();
        if (playerInventoryComp == null)
            return;

        var sortButton:Dynamic;
        try sortButton = HlxRuntime.resolveField(playerInventoryComp, "sortButton") catch (_:Dynamic) return;
        if (sortButton == null)
            return;

        var x:Float;
        var y:Float;
        try {
            x = cast HlxRuntime.resolveField(sortButton, "absX");
            y = cast HlxRuntime.resolveField(sortButton, "absY");
        } catch (_:Dynamic) return;

        ImGui.setNextWindowPos(new ImVec2(x - 38, y));
        ImGui.setNextWindowBgAlpha(0);
        var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
            | ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoSavedSettings
            | ImGuiWindowFlags.NoFocusOnAppearing;
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, new ImVec2(0, 0));
        ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 5.0);
        var base = lockEditMode ? new ImVec4(0.58, 0.43, 0.25, 1) : new ImVec4(0.40, 0.37, 0.35, 1);
        ImGui.pushStyleColor(ImGuiCol.Button, base);
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, new ImVec4(0.48, 0.44, 0.41, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, new ImVec4(0.32, 0.29, 0.27, 1));
        ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.92, 0.86, 0.80, 1));
        if (ImGui.begin("##item-utilities-lock-header", null, flags)) {
            if (ImGui.button("##item-lock-mode", new ImVec2(32, 30)))
                lockEditMode = !lockEditMode;
            drawLockModeIcon();
            if (ImGui.isItemHovered()) {
                setGameButtonCursor();
                ImGui.setTooltip(lockEditMode ? "Stop editing item locks" : "Edit item locks");
            }
        }
        ImGui.end();
        ImGui.popStyleColor(4);
        ImGui.popStyleVar(2);
    }

    static function drawLockModeIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var color = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));
        ImGui.ImDrawList_AddRect(drawList,
            new ImVec2(min.x + 9, min.y + 13),
            new ImVec2(min.x + 23, min.y + 24), color, 2.0, 2.0, 0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 11, min.y + 13),
            new ImVec2(min.x + 11, min.y + 10), color, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 11, min.y + 10),
            new ImVec2(min.x + 14, min.y + 6), color, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 14, min.y + 6),
            new ImVec2(min.x + 19, min.y + 6), color, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 19, min.y + 6),
            new ImVec2(min.x + 21, min.y + 10), color, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 21, min.y + 10),
            new ImVec2(min.x + 21, min.y + 13), color, 2.0);
    }

    static function findInventorySlotForElement(element:Dynamic):Dynamic {
        if (element == null)
            return null;
        for (entry in latestSlots) {
            if (entry == null || entry.slot == null)
                continue;
            if (entry.slot == element)
                return entry.slot;
            try {
                if (HlxRuntime.resolveField(entry.slot, "innerSlot") == element)
                    return entry.slot;
            } catch (_:Dynamic) {}
        }
        return null;
    }

    static function isLockedInventorySlot(slot:Dynamic):Bool {
        if (slot == null)
            return false;
        try {
            var inventory:Dynamic = HlxRuntime.resolveField(slot, "inventory");
            var index:Int = cast HlxRuntime.resolveField(slot, "index");
            if (inventory == null || index < 0)
                return false;
            var stack = arrayGet(getContent(inventory), index);
            var item:Dynamic = stack == null ? null : fieldOrNull(stack, "item");
            return isRuntimeLocked(item);
        } catch (error:Dynamic) {
            logLockError("slot lock lookup", error);
            return false;
        }
    }

    static function handleLockEditClick(slot:Dynamic):Bool {
        if (!enabled.get() || !lockEditMode || slot == null)
            return false;
        try {
            var inventory:Dynamic = HlxRuntime.resolveField(slot, "inventory");
            if (inventory == null || inventory != sourceInventory)
                return false;
            var index:Int = cast HlxRuntime.resolveField(slot, "index");
            if (index < 0)
                return true;
            var stack = arrayGet(getContent(inventory), index);
            var item:Dynamic = stack == null ? null : HlxRuntime.resolveField(stack, "item");
            if (item == null)
                return true;
            if (!isNonStackable(inventory, index))
                return true;

            reconcileLockState();
            var character = resolveCharacterKey();
            var fingerprint = itemFingerprint(item);
            var uid = itemUid(item);
            if (character == null || fingerprint == null || uid == null)
                return true;

            var removeIndex = -1;
            for (recordIndex in 0...lockRecords.length) {
                var record = lockRecords[recordIndex];
                if (recordString(record, "character") != character)
                    continue;
                if (recordString(record, "uid") == uid
                    || (recordString(record, "container") == "inventory"
                        && recordInt(record, "slot", -1) == index
                        && recordString(record, "fingerprint") == fingerprint)) {
                    removeIndex = recordIndex;
                    break;
                }
            }

            if (removeIndex >= 0) {
                lockRecords.splice(removeIndex, 1);
            } else {
                lockRecords.push({
                    character: character,
                    container: "inventory",
                    slot: index,
                    fingerprint: fingerprint,
                    uid: uid,
                    validated: true,
                    pending: 0
                });
            }
            applyLockToLatestSlots();
            saveConfig();
            return true;
        } catch (error:Dynamic) {
            logLockError("edit-mode click", error);
            return true;
        }
    }

    static function reconcileLockState():Void {
        try {
            var character = resolveCharacterKey();
            if (character == null)
                return;
            if (activeCharacterKey != character) {
                activeCharacterKey = character;
                previousItems = null;
                lockStateInitialized = false;
                resetRecordValidation(character);
            }

            var currentItems:Map<String, Dynamic> = new Map();
            var byLocator:Map<String, Dynamic> = new Map();
            var available:Map<String, Bool> = new Map();
            collectCurrentItems(currentItems, byLocator, available);
            if (!available.exists("inventory"))
                return;

            var firstPass = !lockStateInitialized;
            var changed = false;
            var kept:Array<Dynamic> = [];
            var claimed:Map<String, Bool> = new Map();

            for (record in lockRecords) {
                if (recordString(record, "character") != character) {
                    kept.push(record);
                    continue;
                }

                var container = recordString(record, "container");
                var fingerprint = recordString(record, "fingerprint");
                var uid = recordString(record, "uid");
                var validated = recordBool(record, "validated", false);

                if (!validated) {
                    if (!available.exists(container)) {
                        kept.push(record);
                        continue;
                    }
                    var exact = byLocator.get(locatorKey(container, recordInt(record, "slot", -1)));
                    if (exact == null || exact.fingerprint != fingerprint || exact.lockable != true) {
                        changed = true;
                        continue;
                    }
                    record.uid = exact.uid;
                    record.validated = true;
                    record.pending = 0;
                    claimed.set(exact.uid, true);
                    kept.push(record);
                    if (uid != exact.uid)
                        changed = true;
                    continue;
                }

                var current = uid == null ? null : currentItems.get(uid);
                if (current != null) {
                    if (current.fingerprint != fingerprint || current.lockable != true) {
                        changed = true;
                        continue;
                    }
                    if (recordString(record, "container") != current.container
                        || recordInt(record, "slot", -1) != current.slot) {
                        record.container = current.container;
                        record.slot = current.slot;
                        changed = true;
                    }
                    record.pending = 0;
                    claimed.set(uid, true);
                    kept.push(record);
                    continue;
                }

                // Only a lock that was already validated in this running session
                // may follow an observed removal/addition transition. Restored
                // records never use this search path.
                var candidates:Array<Dynamic> = [];
                for (candidate in currentItems) {
                    if (candidate.fingerprint != fingerprint || candidate.lockable != true)
                        continue;
                    if (claimed.exists(candidate.uid))
                        continue;
                    if (previousItems != null && previousItems.exists(candidate.uid))
                        continue;
                    candidates.push(candidate);
                }

                if (candidates.length == 1) {
                    var moved = candidates[0];
                    record.uid = moved.uid;
                    record.container = moved.container;
                    record.slot = moved.slot;
                    record.pending = 0;
                    claimed.set(moved.uid, true);
                    kept.push(record);
                    changed = true;
                } else if (candidates.length > 1) {
                    // Ambiguous identical-item transitions must never move a lock
                    // to an arbitrary copy.
                    changed = true;
                } else if (!available.exists(container)) {
                    kept.push(record);
                } else {
                    var pending = recordInt(record, "pending", 0) + 1;
                    record.pending = pending;
                    if (pending <= MISSING_LOCK_SCAN_LIMIT)
                        kept.push(record);
                    else
                        changed = true;
                }
            }

            lockRecords = kept;
            previousItems = currentItems;
            lockStateInitialized = true;
            if (changed || firstPass)
                applyLockToLatestSlots();
            if (changed)
                saveConfig();
        } catch (error:Dynamic) logLockError("state reconciliation", error);
    }

    static function collectCurrentItems(current:Map<String, Dynamic>, byLocator:Map<String, Dynamic>,
        available:Map<String, Bool>):Void {
        var storages:Array<Dynamic> = [];
        addStorage(storages, "inventory", sourceInventory);

        var hero = resolveHero();
        var loadout = hero == null ? null : fieldOrNull(hero, "loadout");
        if (loadout != null) {
            var heroInventory = fieldOrNull(loadout, "inventory");
            if (sourceInventory == null && heroInventory != null)
                sourceInventory = heroInventory;
            addStorage(storages, "inventory", heroInventory);
            addStorage(storages, "equipment", fieldOrNull(loadout, "equipment"));
            addStorage(storages, "bank", fieldOrNull(loadout, "bank"));
        }
        addStorage(storages, "bank", bankInventory);

        for (storage in storages) {
            var inventory:Dynamic = storage.inventory;
            var container:String = storage.container;
            var content = getContent(inventory);
            if (content == null)
                continue;
            available.set(container, true);
            for (index in 0...arrayLength(content)) {
                var stack = arrayGet(content, index);
                if (stack == null)
                    continue;
                var item:Dynamic = fieldOrNull(stack, "item");
                var uid = itemUid(item);
                var fingerprint = itemFingerprint(item);
                if (uid == null || fingerprint == null)
                    continue;
                var entry:Dynamic = {
                    uid: uid,
                    fingerprint: fingerprint,
                    container: container,
                    slot: index,
                    inventory: inventory,
                    item: item,
                    lockable: isNonStackable(inventory, index)
                };
                current.set(uid, entry);
                byLocator.set(locatorKey(container, index), entry);
            }
        }
    }

    static function addStorage(storages:Array<Dynamic>, container:String, inventory:Dynamic):Void {
        if (inventory == null)
            return;
        for (storage in storages)
            if (storage.inventory == inventory)
                return;
        storages.push({ container: container, inventory: inventory });
    }

    static inline function locatorKey(container:String, slot:Int):String
        return container + ":" + slot;

    static function isRuntimeLocked(item:Dynamic):Bool {
        if (!enabled.get() || item == null)
            return false;
        var uid = itemUid(item);
        if (uid == null)
            return false;
        for (record in lockRecords) {
            if (recordBool(record, "validated", false)
                && recordString(record, "uid") == uid
                && (activeCharacterKey == null || recordString(record, "character") == activeCharacterKey))
                return true;
        }
        return false;
    }

    static function isNonStackable(inventory:Dynamic, index:Int):Bool {
        try {
            if (inventoryType == null)
                inventoryType = HlxRuntime.resolveType("st.Inventory");
            if (inventoryType == null)
                return false;
            if (getSlotStackSizeMember == null)
                getSlotStackSizeMember = HlxRuntime.resolveMember(inventoryType, "getSlotStackSize");
            if (getSlotStackSizeMember == null)
                return false;
            var maximum:Dynamic = HlxRuntime.callResolved(getSlotStackSizeMember, [inventory, index]);
            return maximum != null && cast maximum <= 1;
        } catch (error:Dynamic) {
            logLockError("stackability check", error);
            return false;
        }
    }

    static function itemUid(item:Dynamic):String {
        if (item == null)
            return null;
        try {
            var value = HlxRuntime.resolveField(item, "__uid");
            return value == null ? null : Std.string(value);
        } catch (_:Dynamic) return null;
    }

    static function itemFingerprint(item:Dynamic):String {
        if (item == null)
            return null;
        try {
            var kind = Std.string(HlxRuntime.resolveField(item, "kind"));
            var flags = Std.string(HlxRuntime.resolveField(item, "flags"));
            var inf:Dynamic = HlxRuntime.resolveField(item, "inf");
            var definition = inf == null ? "null" : Std.string(HlxRuntime.resolveField(inf, "id"));
            var affixes:Dynamic = HlxRuntime.resolveField(item, "afxUIDs");
            var affixParts:Array<String> = [];
            for (index in 0...arrayLength(affixes))
                affixParts.push(Std.string(arrayGet(affixes, index)));
            return definition + "|" + kind + "|" + flags + "|" + affixParts.join(",");
        } catch (error:Dynamic) {
            logLockError("item fingerprint", error);
            return null;
        }
    }

    static function resolveHero():Dynamic {
        if (activeHero != null)
            return activeHero;
        if (activeBankWindow == null)
            return null;
        try {
            if (bankWindowType == null)
                bankWindowType = HlxRuntime.resolveType("ui.win.BankWindow");
            if (bankWindowType == null)
                return null;
            if (getMyHeroMember == null)
                getMyHeroMember = HlxRuntime.resolveMember(bankWindowType, "get_myHero");
            if (getMyHeroMember != null)
                activeHero = HlxRuntime.callResolved(getMyHeroMember, [activeBankWindow]);
        } catch (error:Dynamic) logLockError("hero resolution", error);
        return activeHero;
    }

    static function resolveCharacterKey():String {
        var hero = resolveHero();
        if (hero == null)
            return null;

        var owner = fieldOrNull(hero, "ownerPlayer");
        if (owner == null)
            owner = fieldOrNull(hero, "owner");
        var heroData = fieldOrNull(owner, "heroData");
        var value = firstStringField(heroData, ["databaseID", "databaseKey"]);
        if (value != null)
            return "hero-data:" + value;

        value = firstStringField(hero, ["characterName", "displayName", "name"]);
        if (value != null)
            return "hero:" + value;

        value = firstStringField(owner, ["characterName", "displayName", "name", "playerId", "accountId"]);
        if (value != null)
            return "player:" + value;

        logLockError("character identity", "Farever did not expose a stable character identifier");
        return null;
    }

    static function firstStringField(object:Dynamic, names:Array<String>):String {
        if (object == null)
            return null;
        for (name in names) {
            var value = fieldOrNull(object, name);
            if (value != null) {
                var text = Std.string(value);
                if (text.length > 0 && text != "null")
                    return text;
            }
        }
        return null;
    }

    static function fieldOrNull(object:Dynamic, name:String):Dynamic {
        if (object == null)
            return null;
        try return HlxRuntime.resolveField(object, name) catch (_:Dynamic) return null;
    }

    static function recordString(record:Dynamic, name:String):String {
        var value = Reflect.field(record, name);
        return value == null ? null : Std.string(value);
    }

    static function recordInt(record:Dynamic, name:String, fallback:Int):Int {
        var value = Reflect.field(record, name);
        return value == null ? fallback : cast value;
    }

    static function recordBool(record:Dynamic, name:String, fallback:Bool):Bool {
        var value = Reflect.field(record, name);
        return value == null ? fallback : value == true;
    }

    static function resetLockValidation():Void {
        previousItems = null;
        lockStateInitialized = false;
        if (activeCharacterKey != null)
            resetRecordValidation(activeCharacterKey);
    }

    static function resetRecordValidation(character:String):Void {
        for (record in lockRecords) {
            if (recordString(record, "character") == character) {
                record.validated = false;
                record.pending = 0;
            }
        }
    }

    static function applyLockToLatestSlots():Void {
        for (entry in latestSlots)
            applyLockEntry(entry);
    }

    static function applyLockEntry(entry:Dynamic):Void {
        if (entry == null || entry.slot == null)
            return;
        try {
            var stack = arrayGet(getContent(entry.inventory), entry.index);
            var item:Dynamic = stack == null ? null : fieldOrNull(stack, "item");
            var desired = isRuntimeLocked(item);
            if (desired) {
                var current:Dynamic = HlxRuntime.resolveField(entry.slot, "locked");
                if (current != true)
                    setSlotLocked(entry.slot, true);
                entry.modLocked = true;
                resizeSlotLockBadge(entry.slot);
            } else if (entry.modLocked == true) {
                var current:Dynamic = HlxRuntime.resolveField(entry.slot, "locked");
                if (current == true)
                    setSlotLocked(entry.slot, false);
                entry.modLocked = false;
            }
        } catch (error:Dynamic) logLockError("badge update", error);
    }

    static function clearModLockBadges():Void {
        for (entry in latestSlots) {
            if (entry == null || entry.slot == null || entry.modLocked != true)
                continue;
            try {
                var current:Dynamic = HlxRuntime.resolveField(entry.slot, "locked");
                if (current == true)
                    setSlotLocked(entry.slot, false);
                entry.modLocked = false;
            } catch (error:Dynamic) logLockError("badge clear", error);
        }
    }

    static function setSlotLocked(slot:Dynamic, locked:Bool):Void {
        if (inventorySlotType == null)
            inventorySlotType = HlxRuntime.resolveType("ui.win.InventorySlot");
        if (inventorySlotType == null)
            return;
        if (setSlotLockedMember == null)
            setSlotLockedMember = HlxRuntime.resolveMember(inventorySlotType, "set_locked");
        if (setSlotLockedMember == null) {
            logLockError("native badge setter", "set_locked could not be resolved");
            return;
        }
        try HlxRuntime.callResolved(setSlotLockedMember, [slot, locked])
        catch (error:Dynamic) logLockError("native badge setter", error);
    }

    static function resizeSlotLockBadge(slot:Dynamic):Void {
        var badge = fieldOrNull(slot, "lockedBmp");
        if (badge == null)
            return;
        try {
            HlxRuntime.setField(badge, "scaleX", 0.45);
            HlxRuntime.setField(badge, "scaleY", 0.45);
            HlxRuntime.setField(badge, "x", 35.0);
            HlxRuntime.setField(badge, "y", 3.0);
        } catch (error:Dynamic) logLockError("badge positioning", error);
    }

    static function logLockError(area:String, error:Dynamic):Void {
        var message = Std.string(error);
        var key = area + ":" + message;
        if (lockErrors.exists(key))
            return;
        lockErrors.set(key, true);
        trace("[ItemUtilities] item locking error (" + area + "): " + message);
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
            if (Reflect.hasField(data, "itemLocks")) {
                var saved:Array<Dynamic> = cast Reflect.field(data, "itemLocks");
                if (saved != null) {
                    for (record in saved) {
                        var character = recordString(record, "character");
                        var container = recordString(record, "container");
                        var slot = recordInt(record, "slot", -1);
                        var fingerprint = recordString(record, "fingerprint");
                        var uid = recordString(record, "uid");
                        if (character == null || fingerprint == null || uid == null || slot < 0)
                            continue;
                        if (container != "inventory" && container != "bank" && container != "equipment")
                            continue;
                        lockRecords.push({
                            character: character,
                            container: container,
                            slot: slot,
                            fingerprint: fingerprint,
                            uid: uid,
                            validated: false,
                            pending: 0
                        });
                    }
                }
            }
        } catch (_:Dynamic) {}
    }

    static function saveConfig():Void {
        var savedLocks:Array<Dynamic> = [];
        for (record in lockRecords) {
            savedLocks.push({
                character: recordString(record, "character"),
                container: recordString(record, "container"),
                slot: recordInt(record, "slot", -1),
                fingerprint: recordString(record, "fingerprint"),
                uid: recordString(record, "uid")
            });
        }
        try File.saveContent(CONFIG_PATH, Json.stringify({
            enabled: enabled.get(),
            showDepositMaterials: showDepositMaterials.get(),
            hotkeyKey: hotkeyKey,
            hotkeyCtrl: hotkeyCtrl,
            hotkeyShift: hotkeyShift,
            hotkeyAlt: hotkeyAlt,
            hotkeySuper: hotkeySuper,
            hasSeenMenu: hasSeenMenu,
            itemLocks: savedLocks
        }, null, "  ")) catch (_:Dynamic) {}
    }
}
