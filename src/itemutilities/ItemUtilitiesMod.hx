package itemutilities;

import haxe.Json;
import imgui.ImGui;
import imgui.Enums.ImGuiKey;
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
    static var propertiesType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var h2dObjectType:hl.Bytes;
    static var isTypeMember:hlx.runtime.ResolvedMember;
    static var equalsMember:hlx.runtime.ResolvedMember;
    static var isMaxStackMember:hlx.runtime.ResolvedMember;
    static var getSlotStackSizeMember:hlx.runtime.ResolvedMember;
    static var getNextFreeIndexMember:hlx.runtime.ResolvedMember;
    static var requestTransferMember:hlx.runtime.ResolvedMember;
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
        depositButton = null;
        status = "";
        cancelDeposit();
        refreshInventories();
        installDepositButton();
    }

    @:hlx.postfix(ui.win.TitleWindow.onRemove)
    static function afterTitleWindowRemove(instance:Dynamic, result:Void):Void {
        if (instance != activeBankWindow)
            return;
        cancelDeposit();
        activeBankWindow = null;
        depositButton = null;
        sourceInventory = null;
        bankInventory = null;
    }

    static function draw():Void {
        if (!capturingHotkey && hotkeyPressed())
            settingsOpen.set(!settingsOpen.get());

        if (settingsOpen.get())
            drawSettings();

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
        ImGui.checkbox("Show Deposit Crafting Materials button", showDepositMaterials);
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

        for (index in 0...content.length) {
            var stack:Dynamic = content[index];
            if (stack == null)
                continue;
            var item:Dynamic = HlxRuntime.resolveField(stack, "item");
            if (isCraftingComponent(item))
                transferIndexes.push(index);
        }

        if (transferIndexes.length == 0) {
            status = "No crafting materials to deposit.";
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
            var stack:Dynamic = content == null || sourceIndex >= content.length ? null : content[sourceIndex];
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
                var remaining:Dynamic = current == null || sourceIndex >= current.length ? null : current[sourceIndex];
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
        status = "Deposited all crafting materials.";
    }

    static function findDestination(item:Dynamic):{ index:Int, count:Dynamic } {
        var bankContent = getContent(bankInventory);
        if (bankContent != null) {
            for (index in 0...bankContent.length) {
                var stack:Dynamic = bankContent[index];
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
            // InventoryWindow.init stores the exact live bank inventory directly
            // on the BankWindow. Its owner is the hero, so this avoids relying on
            // the inherited get_myHero method being reflectable through HLX.
            bankInventory = HlxRuntime.resolveField(activeBankWindow, "inventory");
            var hero:Dynamic = bankInventory == null ? null : HlxRuntime.resolveField(bankInventory, "owner");
            var loadout:Dynamic = hero == null ? null : HlxRuntime.resolveField(hero, "loadout");
            sourceInventory = loadout == null ? null : HlxRuntime.resolveField(loadout, "inventory");
        } catch (_:Dynamic) {
            sourceInventory = null;
            bankInventory = null;
        }
        return sourceInventory != null && bankInventory != null;
    }

    static function getContent(inventory:Dynamic):Array<Dynamic> {
        if (inventory == null)
            return null;
        try return cast HlxRuntime.resolveField(inventory, "content") catch (_:Dynamic) return null;
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
            HlxRuntime.callResolved(setTextTipMember, [depositButton, "Deposit Crafting Materials"]);

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
