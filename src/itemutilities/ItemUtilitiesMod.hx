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
import hlx.runtime.Bus;
import hlx.runtime.HlxPrefixResult;

@:build(hlx.runtime.Mod.build())
class ItemUtilitiesMod {
    static inline var CONFIG_PATH = "hlx/mods/item-utilities/config.json";
    static inline var SETTINGS_CHANGED_TOPIC_PREFIX =
        "better-mod-settings/config-changed/";
    static inline var CRAFTING_COMPONENT_TYPE = "CraftingComponent";

    static var enabled = new BoolRef(true);
    static var showDepositMaterials = new BoolRef(true);
    static var showLockVisuals = new BoolRef(true);
    static var sortingIgnoresLockedItems = new BoolRef(false);
    static var presetHotkeyKeys:Array<Int> = [0, 0, 0];

    static var activeBankWindow:Dynamic;
    static var activeScrapWindow:Dynamic;
    static var activeInventoryUI:Dynamic;
    static var activeCharacterUI:Dynamic;
    static var activeInventoryWindow:Dynamic;
    static var openInventoryWindows:Array<{ window:Dynamic, inventory:Dynamic }> = [];
    static var depositButton:Dynamic;
    static var sourceInventory:Dynamic;
    static var bankInventory:Dynamic;
    static var scrapInventory:Dynamic;
    static var scrapInventoryComp:Dynamic;
    static var depositing:Bool = false;
    static var depositMode:Int = 0;
    static var transferIndexes:Array<Int> = [];
    static var transferPosition:Int = 0;
    static var status:String = "";
    static var movedStacks:Int = 0;
    static var recyclerDepositing:Bool = false;
    static var recyclerTransferIndexes:Array<Int> = [];
    static var recyclerTransferPosition:Int = 0;
    static var lockedSortActive:Bool = false;
    static var lockedSortInventory:Dynamic;
    static var lockedSortDesiredItems:Array<Dynamic> = [];
    static var lockedSortTargetIndexes:Array<Int> = [];
    static var lockedSortFixedIndexes:Array<Bool> = [];
    static var lockedSortPosition:Int = 0;
    static var lockedSortCallback:Dynamic;
    static var lockedSortSucceeded:Bool = true;
    static var lockedSortWaiting:Bool = false;
    static var lockedSortPendingMoves:Array<Dynamic> = [];

    static var itemType:hl.Bytes;
    static var inventoryType:hl.Bytes;
    static var bankWindowType:hl.Bytes;
    static var scrapWindowType:hl.Bytes;
    static var scrapStationType:hl.Bytes;
    static var arrayObjType:hl.Bytes;
    static var cursorType:hl.Bytes;
    static var systemType:hl.Bytes;
    static var propertiesType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var h2dObjectType:hl.Bytes;
    static var getBoundsMember:hlx.runtime.ResolvedMember;
    static var isTypeMember:hlx.runtime.ResolvedMember;
    static var equalsMember:hlx.runtime.ResolvedMember;
    static var isMaxStackMember:hlx.runtime.ResolvedMember;
    static var getSlotStackSizeMember:hlx.runtime.ResolvedMember;
    static var getNextFreeIndexMember:hlx.runtime.ResolvedMember;
    static var requestTransferMember:hlx.runtime.ResolvedMember;
    static var getMyHeroMember:hlx.runtime.ResolvedMember;
    static var getScrapInventoryMember:hlx.runtime.ResolvedMember;
    static var isScrappableMember:hlx.runtime.ResolvedMember;
    static var arrayGetDynMember:hlx.runtime.ResolvedMember;
    static var setSystemCursorFn:Dynamic;
    static var buttonCursor:Dynamic;
    static var cursorResolutionAttempted:Bool = false;
    static var cursorErrorLogged:Bool = false;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;
    static var playClickFeedbackMember:hlx.runtime.ResolvedMember;
    static var setTextTipMember:hlx.runtime.ResolvedMember;
    static var setVisibleMember:hlx.runtime.ResolvedMember;
    static var getChildIndexMember:hlx.runtime.ResolvedMember;
    static var addChildAtMember:hlx.runtime.ResolvedMember;
    static var inventoryWindowType:hl.Bytes;
    static var baseElementType:hl.Bytes;
    static var getInventoryWindowHeroMember:hlx.runtime.ResolvedMember;
    static var getBaseElementHeroMember:hlx.runtime.ResolvedMember;
    static var gameAppType:hl.Bytes;
    static var hxdKeyType:hl.Bytes;
    static var isKeyPressedMember:hlx.runtime.ResolvedMember;
    static var getGameAppFn:Dynamic;
    static var getCameraHeroMember:hlx.runtime.ResolvedMember;
    static var eReasonType:hl.Bytes;
    static var lockedItemReason:Dynamic;

    // Item __uid values are hxbit object identities. Farever clones an item
    // during most transfers, so a lock record follows a disappearing UID to
    // the one newly-created item with the same immutable fingerprint.
    static var inventoryComps:Array<Dynamic> = [];
    static var playerInventoryComp:Dynamic;
    static var visibleSlots:Array<Dynamic> = [];
    static var lockEditMode:Bool = false;
    static var lockRecords:Array<Dynamic> = [];
    static var fingerprintCache:Map<String, String> = new Map();
    static var nextLockReconcileAt:Float = 0;
    static var weaponPresets:Array<Dynamic> = [];
    static var selectedWeaponPresets:Array<Dynamic> = [];
    static var selectedWeaponPreset:Int = 0;
    static var selectedWeaponPresetCharacterId:String;
    static var presetEquipQueue:Array<Dynamic> = [];
    static var presetEquipPosition:Int = 0;
    static var presetEquipment:Dynamic;
    static var presetTransferActive:Bool = false;
    static var lockScanInitialized:Bool = false;
    static var activeHero:Dynamic;
    static var lockErrors:Map<String, Bool> = new Map();
    static var activeTooltip:Dynamic;
    static var activeTooltipShownAt:Float = 0;
    static var activeBaseUI:Dynamic;
    static inline var LOCK_MISSING_FRAME_LIMIT = 120;
    static inline var INVENTORY_SLOT_SIZE = 48.0;
    static inline var TOOLTIP_BUTTON_DELAY = 0.2;
    static inline var TOOLTIP_OVERLAP_INSET = 4.0;
    static inline var PRESET_CONTROLS_WIDTH = 254.0;
    static inline var ITEM_FINGERPRINT_VERSION = "v2|";
    static inline var LOCK_RECONCILE_INTERVAL = 0.1;
    static inline var DEPOSIT_CRAFTING = 0;
    static inline var DEPOSIT_ALL = 1;
    static inline var DEPOSIT_FOOD = 2;
    static inline var DEPOSIT_CONSUMABLE = 3;
    static inline var DEPOSIT_DEMON_ENCHANTMENT = 4;
    static inline var DEPOSIT_MISC = 5;

    static function main():Void {
        loadConfig();
        saveConfig();
        Bus.subscribe(
            SETTINGS_CHANGED_TOPIC_PREFIX + HlxRuntime.moduleName(),
            onBetterModSettingsChanged
        );
        ImGui.register(HlxRuntime.moduleName(), draw);
    }

    @:hlx.postfix(ui.win.BankWindow.init)
    static function afterBankInit(instance:Dynamic, result:Void):Void {
        activeBankWindow = instance;
        try bankInventory = HlxRuntime.resolveField(instance, "inventory") catch (_:Dynamic) {}
        depositButton = null;
        status = "";
        cancelDeposit();
        cancelRecyclerDeposit();
        refreshInventories();
    }

    @:hlx.postfix(ui.win.Scrap.init)
    static function afterScrapInit(instance:Dynamic, result:Void):Void {
        activeScrapWindow = instance;
        scrapInventory = resolveScrapInventory(instance);
        scrapInventoryComp = null;
        cancelDeposit();
        cancelRecyclerDeposit();
        selectSourceInventory();
        if (sourceInventory == null)
            ensureHeroInventory();
        selectPlayerInventoryComp();
        selectScrapInventoryComp();
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
            selectPlayerInventoryComp();
        } catch (_:Dynamic) {}
    }

    @:hlx.postfix(ui.win.InventoryUI.init)
    static function afterPlayerInventoryInit(instance:Dynamic, result:Void):Void {
        // InventoryUI is recreated when changing characters. Do not retain the
        // previous hero while the new character's windows are being built.
        activeHero = null;
        fingerprintCache = new Map();
        nextLockReconcileAt = 0;
        activeInventoryUI = instance;
        var comp = fieldOrNull(instance, "inventoryComp");
        var inventory = fieldOrNull(comp, "inventory");
        if (comp != null)
            playerInventoryComp = comp;
        if (inventory != null)
            sourceInventory = inventory;
    }

    @:hlx.postfix(ui.win.CharacterUI.init)
    static function afterCharacterUIInit(instance:Dynamic, result:Void):Void {
        activeCharacterUI = instance;
        syncSelectedWeaponPreset();
    }

    @:hlx.postfix(ui.win.InventoryComp.init)
    static function afterInventoryCompInit(instance:Dynamic, result:Void):Void {
        var inventory = fieldOrNull(instance, "inventory");
        var replaced = false;
        if (inventory != null) {
            for (index in 0...inventoryComps.length) {
                if (fieldOrNull(inventoryComps[index], "inventory") == inventory) {
                    inventoryComps[index] = instance;
                    replaced = true;
                    break;
                }
            }
        }
        if (!replaced && inventoryComps.indexOf(instance) < 0)
            inventoryComps.push(instance);
        selectPlayerInventoryComp();
        selectScrapInventoryComp();
    }

    @:hlx.postfix(ui.win.InventorySlot.init)
    static function afterInventorySlotInit(instance:Dynamic, result:Void):Void {
        registerSlot(instance);
    }

    @:hlx.postfix(ui.win.InventorySlot.checkItemChanged)
    static function afterInventorySlotChanged(instance:Dynamic, force:hl.Ref<Bool>, result:Bool):Bool {
        registerSlot(instance);
        return result;
    }

    @:hlx.postfix(ui.BaseUI.setTip)
    static function afterTooltipSet(instance:Dynamic, element:Dynamic, anchor:Dynamic,
        position:Dynamic, nesting:Dynamic, result:Dynamic):Dynamic {
        activeBaseUI = instance;
        if (result != null) {
            activeTooltip = result;
            activeTooltipShownAt = haxe.Timer.stamp();
        }
        return result;
    }

    @:hlx.postfix(ui.BaseUI.displayWindow)
    static function afterWindowDisplayed(instance:Dynamic, window:Dynamic,
        root:Dynamic, result:Void):Void {
        activeBaseUI = instance;
    }

    @:hlx.prefix(st.Loadout.canSellItem)
    static function preventLockedSale(instance:Dynamic, item:Dynamic):HlxPrefixResult<Bool> {
        return isItemLocked(item) ? SkipWith(false) : Continue;
    }

    // MerchantUI calls sellItem directly, without consulting canSellItem.
    @:hlx.prefix(st.Loadout.sellItem)
    static function preventLockedSaleRequest(instance:Dynamic, item:Dynamic,
        callback:Dynamic):HlxPrefixResult<Dynamic> {
        if (!isItemLocked(item))
            return Continue;
        rejectActionCallback(callback);
        return SkipWith(null);
    }

    @:hlx.prefix(st.Inventory.canRequestDropIndex)
    static function preventLockedDrop(instance:Dynamic, index:Int, count:Bool,
        force:hl.Ref<Bool>, unknown:Null<Int>):HlxPrefixResult<Bool> {
        var item = itemAt(instance, index);
        return isItemLocked(item) ? SkipWith(false) : Continue;
    }

    // InventorySlot's discard actions call requestDropIndex directly.
    @:hlx.prefix(st.Inventory.requestDropIndex)
    static function preventLockedDropRequest(instance:Dynamic, index:Int, count:Bool,
        force:hl.Ref<Bool>, unknown:Null<Int>, callback:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(instance, index);
        if (!isItemLocked(item))
            return Continue;
        rejectActionCallback(callback);
        return SkipWith(null);
    }

    @:hlx.prefix(st.Inventory.canRequestTransfer)
    static function preventLockedTransferCheck(instance:Dynamic, index:Int,
        destination:Dynamic, destinationIndex:Int, force:hl.Ref<Bool>,
        count:Null<Int>):HlxPrefixResult<Bool> {
        var item = itemAt(instance, index);
        return isItemLocked(item) && isProtectedTransferDestination(destination)
            ? SkipWith(false)
            : Continue;
    }

    @:hlx.prefix(st.Inventory.requestTransfer)
    static function preventLockedTransferRequest(instance:Dynamic, index:Int,
        destination:Dynamic, destinationIndex:Int, force:hl.Ref<Bool>,
        count:Null<Int>, callback:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(instance, index);
        if (!isItemLocked(item) || !isProtectedTransferDestination(destination))
            return Continue;
        rejectActionCallback(callback);
        return SkipWith(getLockedItemReason());
    }

    @:hlx.prefix(st.Loadout.checkRequestTransfer)
    static function preventLockedRightClickTransferCheck(instance:Dynamic,
        source:Dynamic, sourceIndex:Int, destination:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(source, sourceIndex);
        return isItemLocked(item) && isProtectedTransferDestination(destination)
            ? SkipWith(getLockedItemReason())
            : Continue;
    }

    @:hlx.prefix(st.Loadout.requestTransfer)
    static function preventLockedRightClickTransferRequest(instance:Dynamic,
        source:Dynamic, sourceIndex:Int, destination:Dynamic,
        callback:Dynamic):HlxPrefixResult<Dynamic> {
        var item = itemAt(source, sourceIndex);
        if (!isItemLocked(item) || !isProtectedTransferDestination(destination))
            return Continue;
        rejectActionCallback(callback);
        return SkipWith(getLockedItemReason());
    }

    static function isProtectedTransferDestination(inventory:Dynamic):Bool {
        return isBankInventory(inventory) || isScrapInventory(inventory);
    }

    static function isScrapInventory(inventory:Dynamic):Bool {
        if (inventory == null)
            return false;
        try {
            return Std.string(inventory).indexOf("ent.interactible.ScrapInventory") == 0;
        } catch (_:Dynamic) {
            return false;
        }
    }

    static function isBankInventory(inventory:Dynamic):Bool {
        if (inventory == null)
            return false;
        if (inventory == bankInventory)
            return true;
        var hero = resolveHero();
        var loadout = fieldOrNull(hero, "loadout");
        return loadout != null && inventory == fieldOrNull(loadout, "bank");
    }

    static function rejectActionCallback(callback:Dynamic):Void {
        if (callback != null)
            try Reflect.callMethod(null, callback, [false]) catch (_:Dynamic) {}
    }

    static function getLockedItemReason():Dynamic {
        if (lockedItemReason != null)
            return lockedItemReason;
        try {
            if (eReasonType == null)
                eReasonType = HlxRuntime.resolveType("EReason");
            if (eReasonType != null)
                lockedItemReason = HlxRuntime.constructEnum(eReasonType, "Custom", ["Item is locked"]);
        } catch (error:Dynamic) logLockError("locked reason", error);
        return lockedItemReason;
    }

    @:hlx.prefix(st.Inventory.requestSort)
    static function ignoreLockedItemsDuringSort(instance:Dynamic, indexes:Array<Int>,
        callback:Dynamic):HlxPrefixResult<Dynamic> {
        if (!sortingIgnoresLockedItems.get() || instance != sourceInventory || indexes == null)
            return Continue;

        var content = getContent(instance);
        if (content == null || !resolveMembers())
            return Continue;

        var fixedIndexes:Array<Bool> = [];
        var lockedCount = 0;
        for (index in 0...arrayLength(content)) {
            var locked = isItemLocked(itemAt(instance, index));
            fixedIndexes.push(locked);
            if (locked)
                lockedCount++;
        }
        if (lockedCount == 0)
            return Continue;

        var desiredItems:Array<Dynamic> = [];
        for (sourceIndex in indexes) {
            var item = itemAt(instance, sourceIndex);
            if (item != null && !isItemLocked(item))
                desiredItems.push(item);
        }

        var targetIndexes:Array<Int> = [];
        for (index in 0...fixedIndexes.length) {
            if (!fixedIndexes[index] && targetIndexes.length < desiredItems.length)
                targetIndexes.push(index);
        }

        cancelLockedSort(false);
        lockedSortActive = true;
        lockedSortInventory = instance;
        lockedSortDesiredItems = desiredItems;
        lockedSortTargetIndexes = targetIndexes;
        lockedSortFixedIndexes = fixedIndexes;
        lockedSortPosition = 0;
        lockedSortCallback = callback;
        lockedSortSucceeded = true;
        lockedSortWaiting = false;
        lockedSortPendingMoves = [];
        return SkipWith(null);
    }

    @:hlx.postfix(ui.win.TitleWindow.onRemove)
    static function afterTitleWindowRemove(instance:Dynamic, result:Void):Void {
        var kept:Array<{ window:Dynamic, inventory:Dynamic }> = [];
        for (entry in openInventoryWindows)
            if (entry.window != instance) kept.push(entry);
        openInventoryWindows = kept;

        if (instance == activeInventoryWindow) {
            lockEditMode = false;
            cancelLockedSort(false);
            activeInventoryWindow = null;
            sourceInventory = null;
            playerInventoryComp = null;
            activeHero = null;
        }
        if (instance == activeInventoryUI) {
            lockEditMode = false;
            cancelLockedSort(false);
            activeInventoryUI = null;
            playerInventoryComp = null;
        }
        if (instance == activeCharacterUI) {
            activeCharacterUI = null;
            cancelPresetTransfer();
        }
        if (instance == activeBankWindow) {
            cancelDeposit();
            activeBankWindow = null;
            depositButton = null;
            bankInventory = null;
        }
        if (instance == activeScrapWindow) {
            cancelRecyclerDeposit();
            activeScrapWindow = null;
            scrapInventory = null;
            scrapInventoryComp = null;
        }
        selectSourceInventory();
        lockScanInitialized = false;
    }

    static function draw():Void {
        if (lockedSortActive && !lockedSortWaiting)
            transferNextLockedSortItem();

        if (activeBankWindow != null && enabled.get() && showDepositMaterials.get())
            drawBankHeaderButton();
        if (activeScrapWindow != null && enabled.get() && showDepositMaterials.get())
            drawRecyclerHeaderButton();

        if (enabled.get()) {
            if (activeInventoryUI == null || !isUiVisible(activeInventoryUI))
                lockEditMode = false;
            ensureHeroInventory();
            syncSelectedWeaponPreset();
            selectPlayerInventoryComp();
            checkPresetHotkeys();
            var now = haxe.Timer.stamp();
            if (now >= nextLockReconcileAt) {
                nextLockReconcileAt = now + LOCK_RECONCILE_INTERVAL;
                reconcileItemLocks();
            }
            drawWeaponPresetButtons();
            if (showLockVisuals.get()) {
                drawLockHeaderButton();
                if (lockEditMode)
                    drawLockSlotOverlays();
                drawLockedItemBadges();
            }
        }

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

        drawBankDepositButton(sortButton, x - 228, y, DEPOSIT_MISC,
            "misc", " Deposit miscellaneous ");
        drawBankDepositButton(sortButton, x - 190, y, DEPOSIT_DEMON_ENCHANTMENT,
            "demon", " Deposit demon enchantment ");
        drawBankDepositButton(sortButton, x - 152, y, DEPOSIT_CONSUMABLE,
            "consumable", " Deposit consumable ");
        drawBankDepositButton(sortButton, x - 114, y, DEPOSIT_FOOD,
            "food", " Deposit food ");
        drawBankDepositButton(sortButton, x - 76, y, DEPOSIT_CRAFTING,
            "materials", " Deposit crafting components ");
        drawBankDepositButton(sortButton, x - 38, y, DEPOSIT_ALL,
            "all", " Deposit all ");
    }

    static function drawRecyclerHeaderButton():Void {
        if (!isUiVisible(activeScrapWindow))
            return;
        if (scrapInventory == null)
            scrapInventory = resolveScrapInventory(activeScrapWindow);
        if (scrapInventoryComp == null
            || fieldOrNull(scrapInventoryComp, "inventory") != scrapInventory)
            selectScrapInventoryComp();

        var sortButton = fieldOrNull(scrapInventoryComp, "sortButton");
        if (sortButton == null || !isUiVisible(sortButton))
            return;

        var xValue = fieldOrNull(sortButton, "absX");
        var yValue = fieldOrNull(sortButton, "absY");
        if (xValue == null || yValue == null)
            return;
        var x:Float = cast xValue;
        x -= 38;
        var y:Float = cast yValue;
        if (buttonCovered(x, y, 32, 30))
            return;

        ImGui.setNextWindowPos(new ImVec2(x, y));
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
        if (!ImGui.begin("##item-utilities-recycler-header", null, flags)) {
            ImGui.end();
            ImGui.popStyleColor(4);
            ImGui.popStyleVar(2);
            return;
        }

        if (ImGui.button("##recycler-deposit-all", new ImVec2(32, 30))) {
            playButtonClickSound(sortButton);
            if (!recyclerDepositing)
                beginRecyclerDeposit();
        }
        drawDepositModeIcon(DEPOSIT_ALL);
        if (ImGui.isItemHovered()) {
            setGameButtonCursor();
            ImGui.setTooltip(" Deposit all ");
        }

        ImGui.end();
        ImGui.popStyleColor(4);
        ImGui.popStyleVar(2);
    }

    static function drawBankDepositButton(sortButton:Dynamic, x:Float, y:Float,
        mode:Int, suffix:String, tooltip:String):Void {
        if (buttonCovered(x, y, 32, 30))
            return;

        // Keep the utility in the Bank header without modifying Domkit's live
        // component tree (doing that after init can invalidate the whole UI).
        ImGui.setNextWindowPos(new ImVec2(x, y));
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
        if (!ImGui.begin("##item-utilities-bank-header-" + suffix, null, flags)) {
            ImGui.end();
            ImGui.popStyleColor(4);
            ImGui.popStyleVar(2);
            return;
        }

        if (ImGui.button("##deposit-" + suffix, new ImVec2(32, 30))) {
            playButtonClickSound(sortButton);
            if (!depositing)
                beginDepositMode(mode);
        }
        drawDepositModeIcon(mode);
        if (ImGui.isItemHovered()) {
            setGameButtonCursor();
            ImGui.setTooltip(tooltip);
        }

        ImGui.end();
        ImGui.popStyleColor(4);
        ImGui.popStyleVar(2);
    }

    static function drawWeaponPresetButtons():Void {
        if (activeCharacterUI == null || !isUiVisible(activeCharacterUI))
            return;
        var appearanceButton = fieldOrNull(activeCharacterUI, "appearanceModeBtn");
        if (appearanceButton == null || !isUiVisible(appearanceButton))
            return;

        var x:Float;
        var y:Float;
        var width:Float = 150;
        var height:Float = 36;
        try {
            x = cast HlxRuntime.resolveField(appearanceButton, "absX");
            y = cast HlxRuntime.resolveField(appearanceButton, "absY");
            var rawWidth = fieldOrNull(appearanceButton, "calculatedWidth");
            var rawHeight = fieldOrNull(appearanceButton, "calculatedHeight");
            if (rawWidth != null) {
                var measuredWidth:Float = cast rawWidth;
                if (measuredWidth > 0)
                    width = measuredWidth;
            }
            if (rawHeight != null) {
                var measuredHeight:Float = cast rawHeight;
                if (measuredHeight > 0)
                    height = measuredHeight;
            }
        } catch (_:Dynamic) return;

        var controlsX = x + width + 32;
        if (buttonCovered(controlsX, y, PRESET_CONTROLS_WIDTH, height))
            return;
        ImGui.setNextWindowPos(new ImVec2(controlsX, y));
        ImGui.setNextWindowBgAlpha(0);
        var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
            | ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoSavedSettings
            | ImGuiWindowFlags.NoFocusOnAppearing;
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, new ImVec2(0, 0));
        ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 6.0);
        ImGui.pushStyleColor(ImGuiCol.Button, new ImVec4(0.70, 0.59, 0.54, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, new ImVec4(0.541, 0.373, 0.275, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, new ImVec4(0.60, 0.48, 0.43, 1));
        ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.98, 0.93, 0.90, 1));
        if (ImGui.begin("##item-utilities-weapon-presets", null, flags)) {
            ImGui.dummy(new ImVec2(56, height));
            var titleMin = ImGui.getItemRectMin();
            var titleColor = ImGui.colorConvertFloat4ToU32(
                new ImVec4(0.43, 0.31, 0.28, 1));
            var drawList = ImGui.getWindowDrawList();
            var titleY = titleMin.y + (height - 14) * 0.5;
            ImGui.ImDrawList_AddText_Vec2(drawList,
                new ImVec2(titleMin.x, titleY), titleColor, "Presets");
            ImGui.ImDrawList_AddText_Vec2(drawList,
                new ImVec2(titleMin.x + 0.8, titleY), titleColor, "Presets");
            ImGui.sameLine();

            for (preset in 0...3) {
                if (preset > 0)
                    ImGui.sameLine();
                var selected = selectedWeaponPreset == preset;
                if (selected) {
                    ImGui.pushStyleColor(ImGuiCol.Button, new ImVec4(0.55, 0.39, 0.34, 1));
                    ImGui.pushStyleColor(ImGuiCol.ButtonHovered, new ImVec4(0.541, 0.373, 0.275, 1));
                    ImGui.pushStyleColor(ImGuiCol.ButtonActive, new ImVec4(0.47, 0.32, 0.28, 1));
                }
                if (ImGui.button(Std.string(preset + 1) + "##weapon-preset",
                    new ImVec2(height, height))) {
                    playButtonClickSound(appearanceButton);
                    selectWeaponPreset(preset);
                    activateWeaponPreset(preset);
                }
                if (selected)
                    ImGui.popStyleColor(3);
                if (ImGui.isItemHovered())
                    setGameButtonCursor();
            }
            ImGui.sameLine();
            if (ImGui.button("Set##weapon-preset", new ImVec2(58, height))) {
                playButtonClickSound(appearanceButton);
                saveCurrentWeaponsToPreset(selectedWeaponPreset);
            }
            if (ImGui.isItemHovered())
                setGameButtonCursor();
        }
        ImGui.end();
        ImGui.popStyleColor(4);
        ImGui.popStyleVar(2);
    }

    static function syncSelectedWeaponPreset():Void {
        var characterId = heroPersistentId(resolveHero());
        if (characterId == null || characterId == selectedWeaponPresetCharacterId)
            return;
        selectedWeaponPresetCharacterId = characterId;
        selectedWeaponPreset = 0;
        for (entry in selectedWeaponPresets) {
            if (recordString(entry, "characterId") == characterId) {
                var preset = recordInt(entry, "preset", 0);
                if (preset >= 0 && preset < 3)
                    selectedWeaponPreset = preset;
                return;
            }
        }
    }

    static function selectWeaponPreset(preset:Int):Void {
        if (preset < 0 || preset >= 3)
            return;
        var characterId = heroPersistentId(resolveHero());
        if (characterId == null)
            return;
        selectedWeaponPresetCharacterId = characterId;
        selectedWeaponPreset = preset;
        for (entry in selectedWeaponPresets) {
            if (recordString(entry, "characterId") == characterId) {
                Reflect.setField(entry, "preset", preset);
                saveConfig();
                return;
            }
        }
        selectedWeaponPresets.push({ characterId: characterId, preset: preset });
        saveConfig();
    }

    static function hasWeaponPreset(preset:Int):Bool {
        return findWeaponPreset(heroPersistentId(resolveHero()), preset) != null;
    }

    static function findWeaponPreset(characterId:String, preset:Int):Dynamic {
        if (characterId == null)
            return null;
        for (entry in weaponPresets)
            if (recordString(entry, "characterId") == characterId
                && recordInt(entry, "preset", -1) == preset)
                return entry;
        return null;
    }

    static function saveCurrentWeaponsToPreset(preset:Int):Void {
        var hero = resolveHero();
        var characterId = heroPersistentId(hero);
        var loadout = fieldOrNull(hero, "loadout");
        var equipment = fieldOrNull(loadout, "equipment");
        if (characterId == null || equipment == null || !resolveMembers())
            return;

        var weapons:Array<Dynamic> = [];
        var content = getContent(equipment);
        for (index in 0...arrayLength(content)) {
            var item = itemAt(equipment, index);
            if (item == null || !isItemType(item, "Weapon"))
                continue;
            weapons.push({
                index: index,
                uid: itemUid(item),
                fingerprint: itemFingerprint(item)
            });
        }

        var existing = findWeaponPreset(characterId, preset);
        if (existing == null)
            weaponPresets.push({
                characterId: characterId,
                preset: preset,
                weapons: weapons
            });
        else
            Reflect.setField(existing, "weapons", weapons);
        saveConfig();
    }

    static function activateWeaponPreset(preset:Int):Void {
        if (presetTransferActive)
            return;
        var hero = resolveHero();
        var characterId = heroPersistentId(hero);
        var saved = findWeaponPreset(characterId, preset);
        var loadout = fieldOrNull(hero, "loadout");
        var equipment = fieldOrNull(loadout, "equipment");
        var weapons:Array<Dynamic> = saved == null ? null : cast Reflect.field(saved, "weapons");
        if (equipment == null || weapons == null || weapons.length == 0
            || !resolveMembers())
            return;

        presetEquipQueue = weapons.copy();
        presetEquipPosition = 0;
        presetEquipment = equipment;
        presetTransferActive = true;
        equipNextPresetWeapon();
    }

    static function equipNextPresetWeapon():Void {
        if (!presetTransferActive)
            return;
        while (presetEquipPosition < presetEquipQueue.length) {
            var saved = presetEquipQueue[presetEquipPosition];
            presetEquipPosition++;
            var targetIndex = recordInt(saved, "index", -1);
            if (targetIndex < 0)
                continue;

            var equipped = itemAt(presetEquipment, targetIndex);
            if (presetWeaponMatches(equipped, saved))
                continue;

            var sourceIndex = findPresetWeaponInInventory(saved);
            if (sourceIndex < 0)
                continue;
            if (!resolveMembers()) {
                cancelPresetTransfer();
                return;
            }

            var callback = function(success:Bool):Void {
                equipNextPresetWeapon();
            };
            try {
                HlxRuntime.callResolved(requestTransferMember, [
                    sourceInventory,
                    sourceIndex,
                    presetEquipment,
                    targetIndex,
                    null,
                    null,
                    callback
                ]);
            } catch (_:Dynamic) {
                equipNextPresetWeapon();
            }
            return;
        }
        cancelPresetTransfer();
    }

    static function findPresetWeaponInInventory(saved:Dynamic):Int {
        var wantedUid = recordString(saved, "uid");
        var wantedFingerprint = recordString(saved, "fingerprint");
        var fingerprintMatch = -1;
        var content = getContent(sourceInventory);
        for (index in 0...arrayLength(content)) {
            var item = itemAt(sourceInventory, index);
            if (item == null || !isItemType(item, "Weapon"))
                continue;
            if (itemUid(item) == wantedUid)
                return index;
            if (fingerprintMatch < 0 && itemFingerprint(item) == wantedFingerprint)
                fingerprintMatch = index;
        }
        return fingerprintMatch;
    }

    static function presetWeaponMatches(item:Dynamic, saved:Dynamic):Bool {
        if (item == null || saved == null)
            return false;
        var wantedUid = recordString(saved, "uid");
        return itemUid(item) == wantedUid
            || itemFingerprint(item) == recordString(saved, "fingerprint");
    }

    static function cancelPresetTransfer():Void {
        presetEquipQueue = [];
        presetEquipPosition = 0;
        presetEquipment = null;
        presetTransferActive = false;
    }

    static function drawLockHeaderButton():Void {
        if (activeInventoryUI == null || !isUiVisible(activeInventoryUI)
            || playerInventoryComp == null)
            return;
        var sortButton = fieldOrNull(playerInventoryComp, "sortButton");
        if (sortButton == null)
            return;

        var x:Float;
        var y:Float;
        try {
            x = cast HlxRuntime.resolveField(sortButton, "absX");
            y = cast HlxRuntime.resolveField(sortButton, "absY");
        } catch (_:Dynamic) return;

        if (buttonCovered(x - 38, y, 32, 30))
            return;

        ImGui.setNextWindowPos(new ImVec2(x - 38, y));
        ImGui.setNextWindowBgAlpha(0);
        var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
            | ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoSavedSettings
            | ImGuiWindowFlags.NoFocusOnAppearing;
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, new ImVec2(0, 0));
        ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 5.0);
        ImGui.pushStyleColor(ImGuiCol.Button,
            lockEditMode ? new ImVec4(0.58, 0.43, 0.25, 1) : new ImVec4(0.40, 0.37, 0.35, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered,
            lockEditMode ? new ImVec4(0.68, 0.52, 0.31, 1) : new ImVec4(0.48, 0.44, 0.41, 1));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive,
            lockEditMode ? new ImVec4(0.49, 0.35, 0.20, 1) : new ImVec4(0.32, 0.29, 0.27, 1));
        ImGui.pushStyleColor(ImGuiCol.Text, new ImVec4(0.92, 0.86, 0.80, 1));

        if (ImGui.begin("##item-utilities-lock-header", null, flags)) {
            if (ImGui.button("##item-lock-mode", new ImVec2(32, 30))) {
                playButtonClickSound(sortButton);
                lockEditMode = !lockEditMode;
            }
            drawLockIcon();
            if (ImGui.isItemHovered()) {
                setGameButtonCursor();
                ImGui.setTooltip(lockEditMode ? " Done editing " : " Edit locks ");
            }
        }
        ImGui.end();
        ImGui.popStyleColor(4);
        ImGui.popStyleVar(2);
    }

    static function drawLockIcon():Void {
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

    static function drawLockSlotOverlays():Void {
        for (entry in visibleSlots) {
            var slot:Dynamic = entry.slot;
            if (!isActiveInventoryGridSlot(entry, slot))
                continue;
            var item = displayedSlotItem(entry, slot);
            if (item == null)
                continue;

            var x:Float;
            var y:Float;
            try {
                if (HlxRuntime.resolveField(slot, "visible") == false)
                    continue;
                x = cast HlxRuntime.resolveField(slot, "absX");
                y = cast HlxRuntime.resolveField(slot, "absY");
            } catch (_:Dynamic) continue;

            if (buttonCovered(x, y, INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE))
                continue;

            ImGui.setNextWindowPos(new ImVec2(x, y));
            ImGui.setNextWindowBgAlpha(0);
            var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
                | ImGuiWindowFlags.NoSavedSettings | ImGuiWindowFlags.NoFocusOnAppearing
                | ImGuiWindowFlags.NoBackground;
            ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, new ImVec2(0, 0));
            if (ImGui.begin("##item-lock-slot-" + entry.index, null, flags)) {
                if (ImGui.invisibleButton("##toggle", new ImVec2(INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)))
                    toggleItemLock(item);
                if (ImGui.isItemHovered())
                    setGameButtonCursor();
            }
            ImGui.end();
            ImGui.popStyleVar();
        }
    }

    static function drawLockedItemBadges():Void {
        if (activeInventoryUI == null || !isUiVisible(activeInventoryUI))
            return;
        for (entry in visibleSlots) {
            var slot:Dynamic = entry.slot;
            if (!isActiveInventoryGridSlot(entry, slot))
                continue;
            var item = displayedSlotItem(entry, slot);
            if (!isItemLocked(item))
                continue;

            var x:Float;
            var y:Float;
            try {
                x = cast HlxRuntime.resolveField(slot, "absX");
                y = cast HlxRuntime.resolveField(slot, "absY");
            } catch (_:Dynamic) continue;
            if (!slotIntersectsInventoryViewport(entry, x, y))
                continue;

            var badgeX = x + 40;
            var badgeY = y + 7;
            if (buttonCovered(badgeX, badgeY, 16, 17))
                continue;

            ImGui.setNextWindowPos(new ImVec2(badgeX, badgeY));
            ImGui.setNextWindowBgAlpha(0);
            var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoMove
                | ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoSavedSettings
                | ImGuiWindowFlags.NoFocusOnAppearing | ImGuiWindowFlags.NoBackground
                | ImGuiWindowFlags.NoInputs;
            ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, new ImVec2(0, 0));
            if (ImGui.begin("##item-lock-badge-" + itemUid(item), null, flags)) {
                ImGui.invisibleButton("##badge", new ImVec2(16, 17));
                var drawList = ImGui.getWindowDrawList();
                var viewport = entry.inventory == sourceInventory
                    ? inventoryViewportBounds()
                    : null;
                if (viewport != null)
                    ImGui.ImDrawList_PushClipRect(drawList,
                        new ImVec2(viewport.left, viewport.top),
                        new ImVec2(viewport.right, viewport.bottom), true);
                drawSmallMetalLockIcon();
                if (viewport != null)
                    ImGui.ImDrawList_PopClipRect(drawList);
            }
            ImGui.end();
            ImGui.popStyleVar();
        }
    }

    static function drawSmallMetalLockIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var metal = ImGui.colorConvertFloat4ToU32(new ImVec4(0.72, 0.76, 0.82, 1));
        var keyhole = ImGui.colorConvertFloat4ToU32(new ImVec4(0.20, 0.22, 0.26, 1));

        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 5, min.y + 8),
            new ImVec2(min.x + 5, min.y + 5), metal, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 5, min.y + 5),
            new ImVec2(min.x + 7, min.y + 2), metal, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 7, min.y + 2),
            new ImVec2(min.x + 10, min.y + 2), metal, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 10, min.y + 2),
            new ImVec2(min.x + 12, min.y + 5), metal, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 12, min.y + 5),
            new ImVec2(min.x + 12, min.y + 8), metal, 2.0);
        ImGui.ImDrawList_AddRectFilled(drawList,
            new ImVec2(min.x + 3, min.y + 7),
            new ImVec2(min.x + 14, min.y + 16), metal, 2.0, 0);
        ImGui.ImDrawList_AddCircleFilled(drawList,
            new ImVec2(min.x + 8.5, min.y + 11), 1.25, keyhole, 8);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 8.5, min.y + 11),
            new ImVec2(min.x + 8.5, min.y + 14), keyhole, 1.5);
    }

    static function drawDepositModeIcon(mode:Int):Void {
        switch (mode) {
            case DEPOSIT_ALL: drawDepositAllIcon();
            case DEPOSIT_FOOD: drawFoodDepositIcon();
            case DEPOSIT_CONSUMABLE: drawConsumableDepositIcon();
            case DEPOSIT_DEMON_ENCHANTMENT: drawDemonDepositIcon();
            case DEPOSIT_MISC: drawMiscDepositIcon();
            default: drawCraftingDepositIcon();
        }
    }

    static function drawCraftingDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var metal = ImGui.colorConvertFloat4ToU32(new ImVec4(0.78, 0.82, 0.86, 1));
        var metalShade = ImGui.colorConvertFloat4ToU32(new ImVec4(0.52, 0.58, 0.64, 1));
        var handle = ImGui.colorConvertFloat4ToU32(new ImVec4(0.63, 0.42, 0.24, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Long upright handle, drawn first so the head sits over it.
        ImGui.ImDrawList_AddRectFilled(drawList,
            new ImVec2(min.x + 9, min.y + 9),
            new ImVec2(min.x + 13, min.y + 19), handle, 1.0, 0);

        // Classic horizontal hammer head: a broad striking face on the left
        // and a narrower peen on the right.
        ImGui.ImDrawList_AddRectFilled(drawList,
            new ImVec2(min.x + 3, min.y + 5),
            new ImVec2(min.x + 12, min.y + 11), metal, 1.0, 0);
        ImGui.ImDrawList_AddQuadFilled(drawList,
            new ImVec2(min.x + 12, min.y + 6),
            new ImVec2(min.x + 18, min.y + 7),
            new ImVec2(min.x + 18, min.y + 9),
            new ImVec2(min.x + 12, min.y + 10), metalShade);

        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawFoodDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var food = ImGui.colorConvertFloat4ToU32(new ImVec4(0.86, 0.42, 0.30, 1));
        var leaf = ImGui.colorConvertFloat4ToU32(new ImVec4(0.55, 0.76, 0.38, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Apple with a leaf.
        ImGui.ImDrawList_AddCircleFilled(drawList,
            new ImVec2(min.x + 11, min.y + 12), 5.5, food, 12);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 11, min.y + 7),
            new ImVec2(min.x + 13, min.y + 4), leaf, 1.5);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 13, min.y + 5),
            new ImVec2(min.x + 17, min.y + 6), leaf, 2.0);
        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawConsumableDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var potion = ImGui.colorConvertFloat4ToU32(new ImVec4(0.55, 0.73, 0.92, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Small potion flask.
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 9, min.y + 5),
            new ImVec2(min.x + 14, min.y + 5), potion, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 10, min.y + 6),
            new ImVec2(min.x + 10, min.y + 10), potion, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 13, min.y + 6),
            new ImVec2(min.x + 13, min.y + 10), potion, 2.0);
        ImGui.ImDrawList_AddTriangleFilled(drawList,
            new ImVec2(min.x + 10, min.y + 9),
            new ImVec2(min.x + 5, min.y + 18),
            new ImVec2(min.x + 16, min.y + 18), potion);
        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawDemonDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var demon = ImGui.colorConvertFloat4ToU32(new ImVec4(0.76, 0.43, 0.86, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Gem flanked by two small horns.
        ImGui.ImDrawList_AddQuadFilled(drawList,
            new ImVec2(min.x + 11, min.y + 7),
            new ImVec2(min.x + 16, min.y + 12),
            new ImVec2(min.x + 11, min.y + 18),
            new ImVec2(min.x + 6, min.y + 12), demon);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 7, min.y + 10),
            new ImVec2(min.x + 4, min.y + 5), demon, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 15, min.y + 10),
            new ImVec2(min.x + 18, min.y + 5), demon, 2.0);
        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawMiscDepositIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var misc = ImGui.colorConvertFloat4ToU32(new ImVec4(0.77, 0.68, 0.53, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Three varied pieces represent miscellaneous items.
        ImGui.ImDrawList_AddCircleFilled(drawList,
            new ImVec2(min.x + 7, min.y + 8), 2.5, misc, 8);
        ImGui.ImDrawList_AddRectFilled(drawList,
            new ImVec2(min.x + 11, min.y + 6),
            new ImVec2(min.x + 16, min.y + 11), misc, 1.0, 0);
        ImGui.ImDrawList_AddTriangleFilled(drawList,
            new ImVec2(min.x + 7, min.y + 13),
            new ImVec2(min.x + 12, min.y + 18),
            new ImVec2(min.x + 3, min.y + 18), misc);
        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawDepositAllIcon():Void {
        var min = ImGui.getItemRectMin();
        var drawList = ImGui.getWindowDrawList();
        var star = ImGui.colorConvertFloat4ToU32(new ImVec4(0.91, 0.70, 0.39, 1));
        var mark = ImGui.colorConvertFloat4ToU32(new ImVec4(0.94, 0.89, 0.83, 1));

        // Four-point sparkle communicates "all" without crowding the icon.
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 11, min.y + 5),
            new ImVec2(min.x + 11, min.y + 18), star, 2.5);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 5, min.y + 11),
            new ImVec2(min.x + 17, min.y + 11), star, 2.5);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 7, min.y + 7),
            new ImVec2(min.x + 15, min.y + 15), star, 1.5);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 15, min.y + 7),
            new ImVec2(min.x + 7, min.y + 15), star, 1.5);

        drawDepositArrowAndBucket(min, drawList, mark);
    }

    static function drawDepositArrowAndBucket(min:ImVec2, drawList:Dynamic,
        mark:Int):Void {

        // Down arrow and receiving tray communicate "deposit" at a glance.
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 23, min.y + 6),
            new ImVec2(min.x + 23, min.y + 16), mark, 2.0);
        ImGui.ImDrawList_AddTriangleFilled(drawList,
            new ImVec2(min.x + 19, min.y + 14),
            new ImVec2(min.x + 27, min.y + 14),
            new ImVec2(min.x + 23, min.y + 19), mark);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 18, min.y + 23),
            new ImVec2(min.x + 28, min.y + 23), mark, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 18, min.y + 19),
            new ImVec2(min.x + 18, min.y + 23), mark, 2.0);
        ImGui.ImDrawList_AddLine(drawList,
            new ImVec2(min.x + 28, min.y + 19),
            new ImVec2(min.x + 28, min.y + 23), mark, 2.0);
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
        beginDepositMode(DEPOSIT_CRAFTING);
    }

    static function beginDepositMode(mode:Int):Void {
        if (!refreshInventories() || !resolveMembers()) {
            status = "Inventory is not ready.";
            return;
        }

        cancelRecyclerDeposit();
        depositMode = mode;
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
            if (item != null && matchesDepositMode(item))
                transferIndexes.push(index);
        }

        if (transferIndexes.length == 0) {
            status = "No matching unlocked items to deposit.";
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
            if (item == null || !matchesDepositMode(item)) {
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
                    // A rejected transfer must not abort the remaining batch.
                    transferPosition++;
                    transferNext();
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
                transferPosition++;
                transferNext();
            }
            return;
        }

        depositing = false;
        status = "Deposited all matching unlocked items.";
    }

    static function beginRecyclerDeposit():Void {
        if (!refreshRecyclerInventories() || !resolveRecyclerMembers())
            return;

        cancelDeposit();
        recyclerTransferIndexes = [];
        recyclerTransferPosition = 0;

        var content = getContent(sourceInventory);
        if (content == null)
            return;

        for (index in 0...arrayLength(content)) {
            var item = itemAt(sourceInventory, index);
            if (item != null && !isItemLocked(item) && isRecyclerEligible(item))
                recyclerTransferIndexes.push(index);
        }

        if (recyclerTransferIndexes.length == 0)
            return;

        recyclerDepositing = true;
        transferNextToRecycler();
    }

    static function transferNextToRecycler():Void {
        if (!recyclerDepositing || activeScrapWindow == null
            || !isUiVisible(activeScrapWindow)) {
            cancelRecyclerDeposit();
            return;
        }

        var content = getContent(sourceInventory);
        while (recyclerTransferPosition < recyclerTransferIndexes.length) {
            var sourceIndex = recyclerTransferIndexes[recyclerTransferPosition];
            var item = content == null || sourceIndex >= arrayLength(content)
                ? null
                : itemAt(sourceInventory, sourceIndex);
            if (item == null || isItemLocked(item) || !isRecyclerEligible(item)) {
                recyclerTransferPosition++;
                continue;
            }

            var free:Dynamic;
            try {
                free = HlxRuntime.callResolved(getNextFreeIndexMember, [scrapInventory, item]);
            } catch (_:Dynamic) {
                recyclerTransferPosition++;
                continue;
            }
            var destinationIndex:Int = cast free;
            if (destinationIndex < 0) {
                cancelRecyclerDeposit();
                return;
            }

            var callback = function(success:Bool):Void {
                if (!recyclerDepositing)
                    return;
                // Locked items, server-side eligibility changes, and other
                // rejected transfers should not abort the rest of the batch.
                recyclerTransferPosition++;
                transferNextToRecycler();
            };

            try {
                HlxRuntime.callResolved(requestTransferMember, [
                    sourceInventory,
                    sourceIndex,
                    scrapInventory,
                    destinationIndex,
                    null,
                    null,
                    callback
                ]);
            } catch (_:Dynamic) {
                recyclerTransferPosition++;
                transferNextToRecycler();
            }
            return;
        }

        cancelRecyclerDeposit();
    }

    static function isRecyclerEligible(item:Dynamic):Bool {
        if (item == null || isScrappableMember == null)
            return false;
        try return HlxRuntime.callResolved(isScrappableMember, [item]) == true
        catch (_:Dynamic) return false;
    }

    static function transferNextLockedSortItem():Void {
        if (!lockedSortActive || lockedSortInventory == null) {
            cancelLockedSort(false);
            return;
        }

        if (lockedSortPendingMoves.length > 0) {
            dispatchLockedSortMove();
            return;
        }

        while (lockedSortPosition < lockedSortDesiredItems.length
            && lockedSortPosition < lockedSortTargetIndexes.length) {
            var desiredItem = lockedSortDesiredItems[lockedSortPosition];
            var targetIndex = lockedSortTargetIndexes[lockedSortPosition];
            var targetItem = itemAt(lockedSortInventory, targetIndex);

            // A lock added while sorting is in progress becomes fixed
            // immediately, even though it was not part of the initial set.
            if (isItemLocked(targetItem)) {
                lockedSortSucceeded = false;
                lockedSortPosition++;
                continue;
            }
            if (itemsEqual(targetItem, desiredItem)) {
                lockedSortPosition++;
                continue;
            }

            var sourceIndex = -1;
            var content = getContent(lockedSortInventory);
            for (index in 0...arrayLength(content)) {
                if (index == targetIndex
                    || (index < lockedSortFixedIndexes.length
                        && lockedSortFixedIndexes[index]))
                    continue;
                var candidate = itemAt(lockedSortInventory, index);
                if (!isItemLocked(candidate) && itemsEqual(candidate, desiredItem)) {
                    sourceIndex = index;
                    break;
                }
            }

            if (sourceIndex < 0) {
                lockedSortSucceeded = false;
                lockedSortPosition++;
                continue;
            }

            if (targetItem == null) {
                lockedSortPendingMoves.push({
                    source: sourceIndex,
                    destination: targetIndex
                });
            } else {
                // Farever's own compression code only requests transfers into
                // empty slots. Use one unlocked empty slot as a temporary so
                // an occupied target is reordered through the same safe path.
                var emptyIndex = -1;
                for (index in 0...arrayLength(content)) {
                    if (index != sourceIndex && index != targetIndex
                        && (index >= lockedSortFixedIndexes.length
                            || !lockedSortFixedIndexes[index])
                        && itemAt(lockedSortInventory, index) == null) {
                        emptyIndex = index;
                        break;
                    }
                }
                if (emptyIndex >= 0) {
                    lockedSortPendingMoves.push({
                        source: targetIndex,
                        destination: emptyIndex
                    });
                    lockedSortPendingMoves.push({
                        source: sourceIndex,
                        destination: targetIndex
                    });
                    lockedSortPendingMoves.push({
                        source: emptyIndex,
                        destination: sourceIndex
                    });
                } else {
                    // A completely full inventory has no temporary slot. The
                    // native transfer path can swap two different stacks.
                    lockedSortPendingMoves.push({
                        source: sourceIndex,
                        destination: targetIndex
                    });
                }
            }
            dispatchLockedSortMove();
            return;
        }

        finishLockedSort();
    }

    static function dispatchLockedSortMove():Void {
        if (!lockedSortActive || lockedSortWaiting
            || lockedSortPendingMoves.length == 0)
            return;
        var move = lockedSortPendingMoves[0];
        var sourceIndex:Int = cast Reflect.field(move, "source");
        var destinationIndex:Int = cast Reflect.field(move, "destination");
        var callback = function(success:Bool):Void {
            if (!lockedSortActive)
                return;
            lockedSortWaiting = false;
            if (!success) {
                lockedSortSucceeded = false;
                finishLockedSort();
                return;
            }
            lockedSortPendingMoves.shift();
            if (lockedSortPendingMoves.length == 0)
                lockedSortPosition++;
        };

        try {
            lockedSortWaiting = true;
            HlxRuntime.callResolved(requestTransferMember, [
                lockedSortInventory,
                sourceIndex,
                lockedSortInventory,
                destinationIndex,
                null,
                null,
                callback
            ]);
        } catch (_:Dynamic) {
            lockedSortWaiting = false;
            lockedSortSucceeded = false;
            finishLockedSort();
        }
    }

    static function itemsEqual(left:Dynamic, right:Dynamic):Bool {
        if (left == null || right == null || equalsMember == null)
            return left == right;
        try return HlxRuntime.callResolved(equalsMember, [left, right]) == true
        catch (_:Dynamic) return left == right;
    }

    static function finishLockedSort():Void {
        var callback = lockedSortCallback;
        var success = lockedSortSucceeded;
        cancelLockedSort(false);
        if (callback != null)
            try Reflect.callMethod(null, callback, [success]) catch (_:Dynamic) {}
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
        return isItemType(item, CRAFTING_COMPONENT_TYPE);
    }

    static function matchesDepositMode(item:Dynamic):Bool {
        if (item == null || isItemLocked(item))
            return false;
        return switch (depositMode) {
            case DEPOSIT_ALL: true;
            case DEPOSIT_FOOD: isItemType(item, "Food");
            case DEPOSIT_CONSUMABLE:
                isItemType(item, "Consumable") && !isItemType(item, "Food")
                    && !isDemonEnchantment(item);
            case DEPOSIT_DEMON_ENCHANTMENT: isDemonEnchantment(item);
            case DEPOSIT_MISC:
                isItemType(item, "Misc") && !isDemonEnchantment(item);
            default: isCraftingComponent(item);
        };
    }

    static function isDemonEnchantment(item:Dynamic):Bool {
        return isItemType(item, "AugmentDemon")
            || isItemType(item, "AugmentDemonSigil");
    }

    static function isItemType(item:Dynamic, type:String):Bool {
        if (item == null || isTypeMember == null)
            return false;
        try {
            return HlxRuntime.callResolved(isTypeMember, [item, type]) == true;
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

    static function refreshRecyclerInventories():Bool {
        if (activeScrapWindow == null || !isUiVisible(activeScrapWindow))
            return false;
        try {
            if (scrapInventory == null)
                scrapInventory = resolveScrapInventory(activeScrapWindow);
            selectSourceInventory();
            if (sourceInventory == null)
                ensureHeroInventory();
            selectPlayerInventoryComp();
            selectScrapInventoryComp();
        } catch (_:Dynamic) {
            return false;
        }
        return sourceInventory != null && scrapInventory != null
            && scrapInventoryComp != null;
    }

    static function resolveScrapInventory(window:Dynamic):Dynamic {
        if (window == null)
            return null;
        try {
            if (scrapWindowType == null)
                scrapWindowType = HlxRuntime.resolveType("ui.win.Scrap");
            if (scrapWindowType != null && getScrapInventoryMember == null)
                getScrapInventoryMember = HlxRuntime.resolveMember(
                    scrapWindowType,
                    "get_inventory"
                );
            return getScrapInventoryMember == null
                ? null
                : HlxRuntime.callResolved(getScrapInventoryMember, [window]);
        } catch (error:Dynamic) {
            logLockError("recycler inventory", error);
            return null;
        }
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
            if (entry.window == activeBankWindow || entry.inventory == bankInventory
                || entry.window == activeScrapWindow || entry.inventory == scrapInventory)
                continue;
            activeInventoryWindow = entry.window;
            sourceInventory = entry.inventory;
            return;
        }
    }

    static function ensureHeroInventory():Void {
        if (sourceInventory != null)
            return;
        var hero = resolveHero();
        var loadout = fieldOrNull(hero, "loadout");
        if (loadout != null)
            sourceInventory = fieldOrNull(loadout, "inventory");
    }

    static function selectPlayerInventoryComp():Void {
        playerInventoryComp = null;
        if (sourceInventory == null)
            return;

        if (activeInventoryUI != null) {
            var inventoryUiComp = fieldOrNull(activeInventoryUI, "inventoryComp");
            if (inventoryUiComp != null
                && fieldOrNull(inventoryUiComp, "inventory") == sourceInventory) {
                playerInventoryComp = inventoryUiComp;
                return;
            }
        }

        // InventoryWindow.init creates and assigns its `comp` before this
        // mod's postfix runs. Prefer that direct reference: InventoryComp.init
        // is not reliably dispatched by every HLX/Farever build.
        if (activeInventoryWindow != null) {
            var directComp = fieldOrNull(activeInventoryWindow, "comp");
            if (directComp != null && fieldOrNull(directComp, "inventory") == sourceInventory) {
                playerInventoryComp = directComp;
                return;
            }
        }

        for (comp in inventoryComps) {
            if (fieldOrNull(comp, "inventory") == sourceInventory) {
                playerInventoryComp = comp;
                return;
            }
        }
    }

    static function selectScrapInventoryComp():Void {
        scrapInventoryComp = null;
        if (scrapInventory == null)
            return;
        for (comp in inventoryComps) {
            if (fieldOrNull(comp, "inventory") == scrapInventory
                && (activeScrapWindow == null
                    || isAncestorOf(activeScrapWindow, comp))) {
                scrapInventoryComp = comp;
                return;
            }
        }
    }

    static function isUiVisible(object:Dynamic):Bool {
        if (object == null || fieldOrNull(object, "parent") == null)
            return false;
        var current = object;
        while (current != null) {
            if (fieldOrNull(current, "visible") == false)
                return false;
            current = fieldOrNull(current, "parent");
        }
        return true;
    }

    static function inventoryViewportBounds():{ left:Float, top:Float, right:Float, bottom:Float } {
        var viewport = fieldOrNull(playerInventoryComp, "invContent");
        if (viewport == null || !isUiVisible(viewport))
            return null;
        var rawWidth = fieldOrNull(viewport, "calculatedWidth");
        var rawHeight = fieldOrNull(viewport, "calculatedHeight");
        var rawLeft = fieldOrNull(viewport, "absX");
        var rawTop = fieldOrNull(viewport, "absY");
        if (rawWidth == null || rawHeight == null || rawLeft == null || rawTop == null)
            return null;
        var width:Float = cast rawWidth;
        var height:Float = cast rawHeight;
        var left:Float = cast rawLeft;
        var top:Float = cast rawTop;
        if (width <= 0 || height <= 0)
            return null;
        return {
            left: left,
            top: top,
            right: left + width,
            bottom: top + height
        };
    }

    static function slotIntersectsInventoryViewport(entry:Dynamic, x:Float, y:Float):Bool {
        var viewport = inventoryViewportBounds();
        return viewport != null
            && x < viewport.right && x + INVENTORY_SLOT_SIZE > viewport.left
            && y < viewport.bottom && y + INVENTORY_SLOT_SIZE > viewport.top;
    }

    static function isActiveInventoryGridSlot(entry:Dynamic, slot:Dynamic):Bool {
        if (slot == null || entry.inventory != sourceInventory || !isUiVisible(slot))
            return false;
        var viewport = fieldOrNull(playerInventoryComp, "invContent");
        return viewport != null && isUiVisible(viewport) && isAncestorOf(viewport, slot);
    }

    static function displayedSlotItem(entry:Dynamic, slot:Dynamic):Dynamic {
        var item = fieldOrNull(slot, "item");
        return item != null ? item : itemAt(entry.inventory, entry.index);
    }

    static function registerSlot(slot:Dynamic):Void {
        var inventory = fieldOrNull(slot, "inventory");
        var rawIndex = fieldOrNull(slot, "index");
        if (inventory == null || rawIndex == null)
            return;
        var index:Int = cast rawIndex;
        for (entry in visibleSlots) {
            // InventorySlot instances are also created for item tooltips and
            // equipment previews. Track each concrete UI object separately:
            // keying by inventory/index lets a hover-created slot replace the
            // real grid slot and leaves its badge at the tooltip's coordinates.
            if (entry.slot == slot) {
                entry.inventory = inventory;
                entry.index = index;
                return;
            }
        }
        visibleSlots.push({ inventory: inventory, index: index, slot: slot });
    }

    static function buttonCovered(x:Float, y:Float, width:Float, height:Float):Bool {
        return tooltipOverlaps(x, y, width, height)
            || windowOverlaps(x, y, width, height);
    }

    static function tooltipOverlaps(x:Float, y:Float, width:Float, height:Float):Bool {
        try {
            var tip = activeTooltip;
            if (tip == null || fieldOrNull(tip, "parent") == null
                || fieldOrNull(tip, "visible") == false)
                return false;
            if (haxe.Timer.stamp() - activeTooltipShownAt < TOOLTIP_BUTTON_DELAY)
                return false;

            // Ignore the tooltip's transparent outer padding/shadow so a
            // merely adjacent tooltip does not make the button disappear.
            return objectOverlaps(tip, x, y, width, height, TOOLTIP_OVERLAP_INSET);
        } catch (error:Dynamic) {
            logLockError("tooltip bounds", error);
            return false;
        }
    }

    static function windowOverlaps(x:Float, y:Float, width:Float, height:Float):Bool {
        try {
            var windows = fieldOrNull(activeBaseUI, "windows");
            for (index in 0...arrayLength(windows)) {
                var window = arrayGet(windows, index);
                if (window == null || window == activeBankWindow
                    || window == activeScrapWindow
                    || window == activeCharacterUI
                    || window == activeInventoryWindow
                    || isAncestorOf(window, activeInventoryUI)
                    || isAncestorOf(window, playerInventoryComp))
                    continue;
                if (fieldOrNull(window, "parent") == null
                    || fieldOrNull(window, "visible") == false)
                    continue;
                if (objectOverlaps(window, x, y, width, height, 0))
                    return true;
            }
        } catch (error:Dynamic) {
            logLockError("window bounds", error);
        }
        return false;
    }

    static function isAncestorOf(ancestor:Dynamic, object:Dynamic):Bool {
        if (ancestor == null || object == null)
            return false;
        var current = object;
        while (current != null) {
            if (current == ancestor)
                return true;
            current = fieldOrNull(current, "parent");
        }
        return false;
    }

    static function objectOverlaps(object:Dynamic, x:Float, y:Float,
        width:Float, height:Float, inset:Float):Bool {
        if (h2dObjectType == null)
            h2dObjectType = HlxRuntime.resolveType("h2d.Object");
        if (h2dObjectType != null && getBoundsMember == null)
            getBoundsMember = HlxRuntime.resolveMember(h2dObjectType, "getBounds");
        if (getBoundsMember == null)
            return false;

        // getBounds(null, null) returns the final screen-space rectangle.
        var bounds:Dynamic = HlxRuntime.callResolved(getBoundsMember, [object, null, null]);
        if (bounds == null)
            return false;
        var left:Float = cast HlxRuntime.resolveField(bounds, "xMin") + inset;
        var top:Float = cast HlxRuntime.resolveField(bounds, "yMin") + inset;
        var right:Float = cast HlxRuntime.resolveField(bounds, "xMax") - inset;
        var bottom:Float = cast HlxRuntime.resolveField(bounds, "yMax") - inset;
        return x < right && x + width > left && y < bottom && y + height > top;
    }

    static function toggleItemLock(item:Dynamic):Void {
        var uid = itemUid(item);
        var fingerprint = itemFingerprint(item);
        var characterId = heroPersistentId(resolveHero());
        if (uid == null || fingerprint == null || characterId == null)
            return;
        for (index in 0...lockRecords.length) {
            if (recordString(lockRecords[index], "uid") == uid
                && recordString(lockRecords[index], "characterId") == characterId) {
                lockRecords.splice(index, 1);
                saveConfig();
                return;
            }
        }
        var current:Map<String, Dynamic> = new Map();
        collectTrackedItems(current);
        var tracked = current.get(uid);
        if (tracked == null || tracked.characterId == null)
            return;
        // The item was explicitly interacted with, so refresh its cache even
        // if its UID survived an upgrade or augmentation.
        tracked.fingerprint = fingerprint;
        fingerprintCache.set(uid, fingerprint);
        lockRecords.push({
            uid: uid,
            fingerprint: fingerprint,
            missing: 0,
            known: matchingUids(current, fingerprint),
            location: tracked == null ? null : tracked.location,
            index: tracked == null ? -1 : tracked.index,
            characterId: tracked == null ? null : tracked.characterId,
            restored: true
        });
        saveConfig();
    }

    static function isItemLocked(item:Dynamic):Bool {
        if (!enabled.get() || item == null)
            return false;
        return hasLockUid(itemUid(item));
    }

    static function hasLockUid(uid:String):Bool {
        if (uid == null)
            return false;
        var characterId = heroPersistentId(resolveHero());
        if (characterId == null)
            return false;
        for (record in lockRecords)
            if (recordString(record, "uid") == uid
                && recordString(record, "characterId") == characterId)
                return true;
        return false;
    }

    static function reconcileItemLocks():Void {
        var current:Map<String, Dynamic> = new Map();
        collectTrackedItems(current);
        if (!lockScanInitialized) {
            lockScanInitialized = true;
        }

        var changed = false;
        // Migrate fingerprints written by older releases. Those fingerprints
        // omitted rarity and upgrade state, so only trust the exact UID or a
        // same-kind item still occupying the saved slot.
        for (record in lockRecords) {
            var oldFingerprint = recordString(record, "fingerprint");
            if (oldFingerprint == null
                || StringTools.startsWith(oldFingerprint, ITEM_FINGERPRINT_VERSION))
                continue;
            var separator = oldFingerprint.indexOf("|");
            var oldKind = separator < 0 ? oldFingerprint
                : oldFingerprint.substr(0, separator);
            var uid = recordString(record, "uid");
            var tracked = uid == null ? null : current.get(uid);
            if (tracked == null || !recordAppliesToTrackedItem(record, tracked)
                || tracked.kind != oldKind) {
                tracked = null;
                for (candidateUid in current.keys()) {
                    var candidate = current.get(candidateUid);
                    if (candidate.kind == oldKind
                        && recordAppliesToTrackedItem(record, candidate)
                        && isSavedSlot(record, candidate)) {
                        tracked = candidate;
                        break;
                    }
                }
            }
            if (tracked != null) {
                record.uid = tracked.uid;
                record.fingerprint = tracked.fingerprint;
                record.known = matchingUids(current, tracked.fingerprint);
                record.missing = 0;
                record.restored = true;
                updateRecordLocation(record, tracked);
                changed = true;
            }
        }

        var claimed:Map<String, Bool> = new Map();
        for (record in lockRecords) {
            var uid = recordString(record, "uid");
            var exact = uid == null ? null : current.get(uid);
            if (exact != null && recordAppliesToTrackedItem(record, exact)
                && (Reflect.field(record, "restored") == true
                    || isSavedSlot(record, exact))) {
                // Only confirmed locked items need a live refresh. All other
                // inventory entries use the UID cache populated below.
                var liveFingerprint = itemFingerprint(exact.item);
                if (liveFingerprint != null) {
                    exact.fingerprint = liveFingerprint;
                    fingerprintCache.set(uid, liveFingerprint);
                }
                record.missing = 0;
                record.restored = true;
                // A split creates another item with the same fingerprint but
                // leaves this source UID intact. Remember every identical UID
                // seen while the lock identity is confirmed so the unlocked
                // split-off stack cannot steal the lock when the source stack
                // is moved and receives a replacement UID later.
                if (recordString(record, "fingerprint") != exact.fingerprint) {
                    record.fingerprint = exact.fingerprint;
                    changed = true;
                }
                record.known = matchingUids(current, exact.fingerprint);
                if (updateRecordLocation(record, exact)) changed = true;
                claimed.set(uid, true);
            }
        }

        var kept:Array<Dynamic> = [];
        for (record in lockRecords) {
            // Bank locks belonged to the previous behavior. Locked items now
            // stay with the character and cannot be deposited.
            if (recordString(record, "location") == "bank") {
                changed = true;
                continue;
            }
            var uid = recordString(record, "uid");
            var exact = uid == null ? null : current.get(uid);
            if (exact != null && claimed.exists(uid)) {
                kept.push(record);
                continue;
            }

            var fingerprint = recordString(record, "fingerprint");
            var known:Array<Dynamic> = cast Reflect.field(record, "known");
            var candidates:Array<Dynamic> = [];
            var matching = matchingUids(current, fingerprint);
            for (candidateUid in current.keys()) {
                var candidate = current.get(candidateUid);
                if (candidate.fingerprint != fingerprint || claimed.exists(candidateUid))
                    continue;
                if (!recordAppliesToTrackedItem(record, candidate))
                    continue;
                // Existing identical items were captured when this lock last
                // had a confirmed identity and can never steal the lock.
                if (arrayContainsString(known, candidateUid))
                    continue;
                candidates.push(candidate);
            }

            var replacement:Dynamic = null;
            // While an inventory is being reconstructed, identical items can
            // appear one at a time. Wait until at least as many copies are
            // visible as when this lock last had a confirmed identity before
            // choosing any newly-created UID.
            var knownCount = known == null ? 0 : known.length;
            var duplicateSetReady = knownCount == 0 || matching.length >= knownCount;
            var savedLocation = recordString(record, "location");
            var savedIndex = recordInt(record, "index", -1);
            if (duplicateSetReady && savedLocation != null && savedIndex >= 0) {
                for (candidate in candidates) {
                    if (candidate.location == savedLocation && candidate.index == savedIndex) {
                        replacement = candidate;
                        break;
                    }
                }
            }
            // During the live session a transfer can legitimately change both
            // container and slot. A record loaded from disk has not established
            // its new runtime identity yet, so never let a lone identical item
            // in another container steal it before the saved container loads.
            if (duplicateSetReady && replacement == null
                && Reflect.field(record, "restored") == true
                && candidates.length == 1)
                replacement = candidates[0];

            if (replacement != null) {
                record.uid = replacement.uid;
                record.missing = 0;
                record.known = matchingUids(current, fingerprint);
                record.restored = true;
                updateRecordLocation(record, replacement);
                claimed.set(replacement.uid, true);
                kept.push(record);
                changed = true;
            } else {
                var missing = recordInt(record, "missing", 0) + 1;
                record.missing = missing;
                // Equipment may not be materialized yet. Keep
                // unresolved persisted records rather than guessing or losing
                // them; a later scan can still restore the exact item.
                kept.push(record);
            }
        }
        lockRecords = kept;
        if (changed) saveConfig();
    }

    static function updateRecordLocation(record:Dynamic, tracked:Dynamic):Bool {
        if (record == null || tracked == null)
            return false;
        var oldLocation = recordString(record, "location");
        var oldIndex = recordInt(record, "index", -1);
        var oldCharacterId = recordString(record, "characterId");
        record.location = tracked.location;
        record.index = tracked.index;
        record.characterId = tracked.characterId;
        return oldLocation != tracked.location || oldIndex != tracked.index
            || oldCharacterId != tracked.characterId;
    }

    static function isSavedSlot(record:Dynamic, tracked:Dynamic):Bool {
        return recordString(record, "location") == tracked.location
            && recordInt(record, "index", -1) == tracked.index;
    }

    static function recordAppliesToTrackedItem(record:Dynamic, tracked:Dynamic):Bool {
        if (record == null || tracked == null || tracked.characterId == null)
            return false;
        return recordString(record, "characterId") == tracked.characterId;
    }

    static function matchingUids(items:Map<String, Dynamic>, fingerprint:String):Array<String> {
        var result:Array<String> = [];
        for (uid in items.keys()) {
            var item = items.get(uid);
            if (item != null && item.fingerprint == fingerprint)
                result.push(uid);
        }
        return result;
    }

    static function arrayContainsString(values:Array<Dynamic>, expected:String):Bool {
        if (values == null)
            return false;
        for (value in values)
            if (Std.string(value) == expected)
                return true;
        return false;
    }

    static function collectTrackedItems(result:Map<String, Dynamic>):Void {
        var inventories:Array<Dynamic> = [];
        var hero = resolveHero();
        var characterId = heroPersistentId(hero);
        addTrackedInventory(inventories, sourceInventory, "inventory", characterId);

        var loadout = fieldOrNull(hero, "loadout");
        if (loadout != null) {
            addTrackedInventory(inventories, fieldOrNull(loadout, "inventory"), "inventory", characterId);
            addTrackedInventory(inventories, fieldOrNull(loadout, "equipment"), "equipment", characterId);
        }

        for (entry in inventories) {
            var inventory = entry.inventory;
            var content = getContent(inventory);
            for (index in 0...arrayLength(content)) {
                var item = itemAt(inventory, index);
                var uid = itemUid(item);
                var fingerprint = uid == null ? null : fingerprintCache.get(uid);
                if (uid != null && fingerprint == null) {
                    fingerprint = itemFingerprint(item);
                    if (fingerprint != null)
                        fingerprintCache.set(uid, fingerprint);
                }
                if (uid != null && fingerprint != null)
                    result.set(uid, { uid: uid, fingerprint: fingerprint,
                        kind: Std.string(fieldOrNull(item, "kind")), item: item,
                        inventory: inventory,
                        location: entry.location, index: index,
                        characterId: entry.characterId });
            }
        }
    }

    static function addTrackedInventory(inventories:Array<Dynamic>, inventory:Dynamic,
        location:String, characterId:String):Void {
        if (inventory == null)
            return;
        for (entry in inventories) {
            if (entry.inventory == inventory) {
                if (entry.characterId == null && characterId != null)
                    entry.characterId = characterId;
                return;
            }
        }
        inventories.push({ inventory: inventory, location: location, characterId: characterId });
    }

    static function heroPersistentId(hero:Dynamic):String {
        var connectionInfo = gameConnectionInfo();
        var heroId = fieldOrNull(connectionInfo, "heroID");
        if (heroId == null)
            return null;
        var value = Std.string(heroId);
        return value.length == 0 || value == "0" ? null : "db:" + value;
    }

    static function gameConnectionInfo():Dynamic {
        return fieldOrNull(currentGameApp(), "connectionInfo");
    }

    static function currentGameApp():Dynamic {
        try {
            if (gameAppType == null)
                gameAppType = HlxRuntime.resolveType("GameApp");
            if (gameAppType != null && getGameAppFn == null)
                getGameAppFn = HlxRuntime.resolveStaticField(gameAppType, "get");
            var app = getGameAppFn == null
                ? null
                : Reflect.callMethod(null, getGameAppFn, []);
            return app;
        } catch (error:Dynamic) {
            logLockError("game app", error);
            return null;
        }
    }

    static function resolveHero():Dynamic {
        if (activeHero != null && fieldOrNull(activeHero, "loadout") != null)
            return activeHero;
        try {
            // Preset hotkeys run even while the inventory and character windows
            // have never been opened. Resolve the active hero directly from the
            // game in that case; UI-owned hero references remain useful fallbacks.
            var app = currentGameApp();
            if (app != null) {
                if (gameAppType != null && getCameraHeroMember == null)
                    getCameraHeroMember = HlxRuntime.resolveMember(
                        gameAppType,
                        "getCameraHero"
                    );
                if (getCameraHeroMember != null)
                    activeHero = HlxRuntime.callResolved(getCameraHeroMember, [app]);
            }
            if (activeInventoryUI != null) {
                if (baseElementType == null)
                    baseElementType = HlxRuntime.resolveType("ui.BaseElement");
                if (baseElementType != null && getBaseElementHeroMember == null)
                    getBaseElementHeroMember = HlxRuntime.resolveMember(baseElementType, "get_myHero");
                if (getBaseElementHeroMember != null)
                    activeHero = HlxRuntime.callResolved(getBaseElementHeroMember, [activeInventoryUI]);
            }
            if (activeHero == null && activeInventoryWindow != null) {
                if (inventoryWindowType == null)
                    inventoryWindowType = HlxRuntime.resolveType("ui.win.InventoryWindow");
                if (inventoryWindowType != null && getInventoryWindowHeroMember == null)
                    getInventoryWindowHeroMember = HlxRuntime.resolveMember(inventoryWindowType, "get_myHero");
                if (getInventoryWindowHeroMember != null)
                    activeHero = HlxRuntime.callResolved(getInventoryWindowHeroMember, [activeInventoryWindow]);
            }
            if (activeHero == null && activeBankWindow != null) {
                if (bankWindowType == null)
                    bankWindowType = HlxRuntime.resolveType("ui.win.BankWindow");
                if (bankWindowType != null && getMyHeroMember == null)
                    getMyHeroMember = HlxRuntime.resolveMember(bankWindowType, "get_myHero");
                if (getMyHeroMember != null)
                    activeHero = HlxRuntime.callResolved(getMyHeroMember, [activeBankWindow]);
            }
        } catch (error:Dynamic) logLockError("hero resolution", error);
        return activeHero;
    }

    static function itemAt(inventory:Dynamic, index:Int):Dynamic {
        var content = getContent(inventory);
        var stack = index < 0 || index >= arrayLength(content) ? null : arrayGet(content, index);
        return stack == null ? null : fieldOrNull(stack, "item");
    }

    static function itemUid(item:Dynamic):String {
        var value = fieldOrNull(item, "__uid");
        return value == null ? null : Std.string(value);
    }

    static function itemFingerprint(item:Dynamic):String {
        if (item == null)
            return null;
        try {
            var parts:Array<String> = [];
            var flags = fieldOrNull(item, "flags");
            var definition = fieldOrNull(item, "inf");
            parts.push(fingerprintValue(fieldOrNull(item, "kind")));
            parts.push(fingerprintValue(fieldOrNull(flags, "value")));
            parts.push(fingerprintArray(fieldOrNull(item, "afxUIDs"), false));
            parts.push(fingerprintValue(fieldOrNull(item, "level")));
            parts.push(fingerprintValue(fieldOrNull(item, "upgradeLevel")));
            parts.push(fingerprintValue(fieldOrNull(item, "rarity")));
            parts.push(fingerprintValue(fieldOrNull(definition, "rarity")));
            parts.push(fingerprintArray(fieldOrNull(item, "slots"), false));
            parts.push(fingerprintArray(fieldOrNull(item, "effects"), true));
            return ITEM_FINGERPRINT_VERSION + Json.stringify(parts);
        } catch (error:Dynamic) {
            logLockError("fingerprint", error);
            return null;
        }
    }

    static function fingerprintValue(value:Dynamic):String {
        return value == null ? "<null>" : Std.string(value);
    }

    static function fingerprintArray(value:Dynamic, weaponEffects:Bool):String {
        if (value == null)
            return "[]";
        // Gear slots and weapon effects are hxbit.ArrayProxyData. Affix UIDs
        // are a native typed array. Unwrap proxies, then read both through the
        // common HashLink array interface.
        var inner = fieldOrNull(value, "array");
        if (inner != null)
            value = inner;
        var parts:Array<String> = [];
        for (index in 0...arrayLength(value)) {
            var entry = arrayGet(value, index);
            if (weaponEffects) {
                parts.push(Json.stringify([
                    fingerprintValue(fieldOrNull(entry, "skill")),
                    fingerprintValue(fieldOrNull(entry, "source"))
                ]));
            } else {
                parts.push(fingerprintValue(entry));
            }
        }
        return Json.stringify(parts);
    }

    static function playButtonClickSound(referenceButton:Dynamic):Void {
        if (referenceButton == null)
            return;
        try {
            if (!resolveUiMembers())
                return;
            if (playClickFeedbackMember == null)
                playClickFeedbackMember = HlxRuntime.resolveMember(uiElementType, "playClickFeedBack");
            if (playClickFeedbackMember == null)
                return;
            // UIElement.click() calls this after a successful native click. It
            // owns the exact UI_Button_Click SFX and visual feedback without
            // invoking the Sort button's action.
            HlxRuntime.callResolved(playClickFeedbackMember, [referenceButton]);
        } catch (error:Dynamic) {
            logLockError("button click sound", error);
        }
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
                arrayObjType = HlxRuntime.resolveType("hl.types.ArrayBase");
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

    static function resolveRecyclerMembers():Bool {
        if (!resolveMembers())
            return false;
        if (scrapStationType == null)
            scrapStationType = HlxRuntime.resolveType("ent.interactible.ScrapStation");
        if (scrapStationType != null && isScrappableMember == null)
            isScrappableMember = HlxRuntime.resolveStaticMember(
                scrapStationType,
                "isScrappable"
            );
        return isScrappableMember != null;
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

    static function cancelRecyclerDeposit():Void {
        recyclerDepositing = false;
        recyclerTransferIndexes = [];
        recyclerTransferPosition = 0;
    }

    static function cancelLockedSort(notifyFailure:Bool):Void {
        var callback = lockedSortCallback;
        lockedSortActive = false;
        lockedSortInventory = null;
        lockedSortDesiredItems = [];
        lockedSortTargetIndexes = [];
        lockedSortFixedIndexes = [];
        lockedSortPosition = 0;
        lockedSortCallback = null;
        lockedSortSucceeded = true;
        lockedSortWaiting = false;
        lockedSortPendingMoves = [];
        if (notifyFailure && callback != null)
            try Reflect.callMethod(null, callback, [false]) catch (_:Dynamic) {}
    }

    static function checkPresetHotkeys():Void {
        if (presetTransferActive)
            return;
        for (preset in 0...3) {
            var key = presetHotkeyKeys[preset];
            if (key > 0 && isGameKeyPressed(key)) {
                selectWeaponPreset(preset);
                activateWeaponPreset(preset);
                return;
            }
        }
    }

    static function isGameKeyPressed(keyCode:Int):Bool {
        if (hxdKeyType == null)
            hxdKeyType = HlxRuntime.resolveType("hxd.Key");
        if (hxdKeyType != null && isKeyPressedMember == null)
            isKeyPressedMember = HlxRuntime.resolveStaticMember(hxdKeyType, "isPressed");
        if (isKeyPressedMember == null)
            return false;
        try return HlxRuntime.callResolved(isKeyPressedMember, [keyCode]) == true
        catch (_:Dynamic) return false;
    }

    static function onBetterModSettingsChanged(_:Dynamic):Void {
        try {
            if (!FileSystem.exists(CONFIG_PATH))
                return;
            var data:Dynamic = Json.parse(File.getContent(CONFIG_PATH));
            var wasEnabled = enabled.get();
            if (Reflect.hasField(data, "enabled"))
                enabled.set(Reflect.field(data, "enabled"));
            if (Reflect.hasField(data, "showDepositMaterials"))
                showDepositMaterials.set(Reflect.field(data, "showDepositMaterials"));
            if (Reflect.hasField(data, "showLockVisuals"))
                showLockVisuals.set(Reflect.field(data, "showLockVisuals"));
            if (Reflect.hasField(data, "sortingIgnoresLockedItems"))
                sortingIgnoresLockedItems.set(Reflect.field(data, "sortingIgnoresLockedItems"));
            loadPresetHotkeyConfig(data);
            if ((!enabled.get() && wasEnabled) || !showDepositMaterials.get()) {
                cancelDeposit();
                cancelRecyclerDeposit();
            }
            if (!enabled.get() || !showLockVisuals.get())
                lockEditMode = false;
            if (!enabled.get() || !sortingIgnoresLockedItems.get())
                cancelLockedSort(false);
            syncDepositButtonVisibility();
        } catch (_:Dynamic) {}
    }

    static function loadConfig():Void {
        try {
            if (!FileSystem.exists(CONFIG_PATH)) return;
            var data:Dynamic = Json.parse(File.getContent(CONFIG_PATH));
            if (Reflect.hasField(data, "enabled")) enabled.set(Reflect.field(data, "enabled"));
            if (Reflect.hasField(data, "showDepositMaterials")) showDepositMaterials.set(Reflect.field(data, "showDepositMaterials"));
            if (Reflect.hasField(data, "showLockVisuals"))
                showLockVisuals.set(Reflect.field(data, "showLockVisuals"));
            if (Reflect.hasField(data, "sortingIgnoresLockedItems"))
                sortingIgnoresLockedItems.set(Reflect.field(data, "sortingIgnoresLockedItems"));
            loadPresetHotkeyConfig(data);
            if (Reflect.hasField(data, "selectedWeaponPresets")) {
                var savedSelections:Array<Dynamic> =
                    cast Reflect.field(data, "selectedWeaponPresets");
                if (savedSelections != null) {
                    for (entry in savedSelections) {
                        var selectionCharacterId = recordString(entry, "characterId");
                        var selectedPreset = recordInt(entry, "preset", -1);
                        if (selectionCharacterId != null
                            && StringTools.startsWith(selectionCharacterId, "db:")
                            && selectedPreset >= 0 && selectedPreset < 3)
                            selectedWeaponPresets.push({
                                characterId: selectionCharacterId,
                                preset: selectedPreset
                            });
                    }
                }
            }
            if (Reflect.hasField(data, "weaponPresets")) {
                var savedPresets:Array<Dynamic> = cast Reflect.field(data, "weaponPresets");
                if (savedPresets != null) {
                    for (entry in savedPresets) {
                        var characterId = recordString(entry, "characterId");
                        var preset = recordInt(entry, "preset", -1);
                        var weapons:Array<Dynamic> = cast Reflect.field(entry, "weapons");
                        if (characterId != null && StringTools.startsWith(characterId, "db:")
                            && preset >= 0 && preset < 3 && weapons != null)
                            weaponPresets.push({
                                characterId: characterId,
                                preset: preset,
                                weapons: weapons
                            });
                    }
                }
            }
            if (Reflect.hasField(data, "lockedItems")) {
                var saved:Array<Dynamic> = cast Reflect.field(data, "lockedItems");
                if (saved != null) {
                    for (record in saved) {
                        var uid = recordString(record, "uid");
                        var fingerprint = recordString(record, "fingerprint");
                        var location = recordString(record, "location");
                        var characterId = recordString(record, "characterId");
                        if (uid != null && fingerprint != null && location != "bank"
                            && characterId != null
                            && StringTools.startsWith(characterId, "db:")) {
                            lockRecords.push({
                                uid: uid,
                                fingerprint: fingerprint,
                                missing: 0,
                                known: [],
                                location: location,
                                index: recordInt(record, "index", -1),
                                characterId: characterId,
                                restored: false
                            });
                        }
                    }
                }
            }
        } catch (_:Dynamic) {}
    }

    static function loadPresetHotkeyConfig(data:Dynamic):Void {
        for (preset in 0...3) {
            var field = "preset" + (preset + 1) + "Hotkey";
            if (Reflect.hasField(data, field))
                presetHotkeyKeys[preset] = cast Reflect.field(data, field);
        }
    }

    static function saveConfig():Void {
        var savedLocks:Array<Dynamic> = [];
        for (record in lockRecords) {
            savedLocks.push({
                uid: recordString(record, "uid"),
                fingerprint: recordString(record, "fingerprint"),
                location: recordString(record, "location"),
                index: recordInt(record, "index", -1),
                characterId: recordString(record, "characterId")
            });
        }
        try {
            File.saveContent(CONFIG_PATH, Json.stringify({
            enabled: enabled.get(),
            showDepositMaterials: showDepositMaterials.get(),
            showLockVisuals: showLockVisuals.get(),
            sortingIgnoresLockedItems: sortingIgnoresLockedItems.get(),
            preset1Hotkey: presetHotkeyKeys[0],
            preset2Hotkey: presetHotkeyKeys[1],
            preset3Hotkey: presetHotkeyKeys[2],
            weaponPresets: weaponPresets,
            selectedWeaponPresets: selectedWeaponPresets,
            lockedItems: savedLocks
            }, null, "  "));
        } catch (_:Dynamic) {}
    }
}
