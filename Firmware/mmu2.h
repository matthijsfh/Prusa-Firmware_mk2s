/// @file
#pragma once
#include "mmu2_protocol_logic.h"

struct E_Step;

namespace MMU2 {

/// @@TODO hmmm, 12 bytes... may be we can reduce that
struct xyz_pos_t {
    float xyz[3];
    xyz_pos_t()=default;
};

// general MMU setup for MK3
enum : uint8_t {
    FILAMENT_UNKNOWN = 0xffU
};

struct Version {
    uint8_t major, minor, build;
};

/// Top-level interface between Logic and Marlin.
/// Intentionally named MMU2 to be (almost) a drop-in replacement for the previous implementation.
/// Most of the public methods share the original naming convention as well.
class MMU2 {
public:
    MMU2();
    
    /// Powers ON the MMU, then initializes the UART and protocol logic
    void Start();
    
    /// Stops the protocol logic, closes the UART, powers OFF the MMU
    void Stop();
    
    /// States of a printer with the MMU:
    /// - Active
    /// - Connecting
    /// - Stopped
    /// 
    /// When the printer's FW starts, the MMU2 mode is either Stopped or NotResponding (based on user's preference).
    /// When the MMU successfully establishes communication, the state changes to Active.
    enum class xState : uint_fast8_t {
        Active, ///< MMU has been detected, connected, communicates and is ready to be worked with.
        Connecting, ///< MMU is connected but it doesn't communicate (yet). The user wants the MMU, but it is not ready to be worked with.
        Stopped ///< The user doesn't want the printer to work with the MMU. The MMU itself is not powered and does not work at all.
    };
    
    inline xState State() const { return state; }
    
    // @@TODO temporary wrappers to make old gcc survive the code
    inline bool Enabled()const { return State() == xState::Active; }

    /// Different levels of resetting the MMU
    enum ResetForm : uint8_t {
        Software = 0, ///< sends a X0 command into the MMU, the MMU will watchdog-reset itself
        ResetPin = 1, ///< trigger the reset pin of the MMU
        CutThePower = 2 ///< power off and power on (that includes +5V and +24V power lines)
    };

    /// Saved print state on error.
    enum SavedState: uint8_t {
        None = 0, // No state saved. 
        ParkExtruder = 1, // The extruder was parked. 
        Cooldown = 2, // The extruder was allowed to cool.
        CooldownPending = 4,
    };

    /// Source of operation error
    enum ReportErrorSource: uint8_t {
        ErrorSourcePrinter = 0,
        ErrorSourceMMU = 1,
    };

    /// Perform a reset of the MMU
    /// @param level physical form of the reset
    void Reset(ResetForm level);
    
    /// Power off the MMU (cut the power)
    void PowerOff();
    
    /// Power on the MMU
    void PowerOn();


    /// The main loop of MMU processing.
    /// Doesn't loop (block) inside, performs just one step of logic state machines.
    /// Also, internally it prevents recursive entries.
    void mmu_loop();

    /// The main MMU command - select a different slot
    /// @param index of the slot to be selected
    /// @returns false if the operation cannot be performed (Stopped)
    bool tool_change(uint8_t index);
    
    /// Handling of special Tx, Tc, T? commands
    bool tool_change(char code, uint8_t slot);

    /// Unload of filament in collaboration with the MMU.
    /// That includes rotating the printer's extruder in order to release filament.
    /// @returns false if the operation cannot be performed (Stopped or cold extruder)
    bool unload();

    /// Load (insert) filament just into the MMU (not into printer's nozzle)
    /// @returns false if the operation cannot be performed (Stopped)
    bool load_filament(uint8_t index);
    
    /// Load (push) filament from the MMU into the printer's nozzle
    /// @returns false if the operation cannot be performed (Stopped or cold extruder)
    bool load_filament_to_nozzle(uint8_t index);

    /// Move MMU's selector aside and push the selected filament forward.
    /// Usable for improving filament's tip or pulling the remaining piece of filament out completely.
    bool eject_filament(uint8_t index, bool recover);

    /// Issue a Cut command into the MMU
    /// Requires unloaded filament from the printer (obviously)
    /// @returns false if the operation cannot be performed (Stopped)
    bool cut_filament(uint8_t index);

    /// Issue a Try-Load command
    /// It behaves very similarly like a ToolChange, but it doesn't load the filament
    /// all the way down to the nozzle. The sole purpose of this operation
    /// is to check, that the filament will be ready for printing.
    bool load_to_bondtech(uint8_t index);

    /// @returns the active filament slot index (0-4) or 0xff in case of no active tool
    uint8_t get_current_tool() const;

    /// @returns the previous active filament slot index (0-4) or 0xff in case of no active tool at boot-up
    inline uint8_t get_previous_tool() const { return previous_extruder; };
    
    /// @returns The filament slot index (0 to 4) that will be loaded next, 0xff in case of no active tool change 
    uint8_t get_tool_change_tool() const;

    bool set_filament_type(uint8_t index, uint8_t type);

    /// Issue a "button" click into the MMU - to be used from Error screens of the MMU
    /// to select one of the 3 possible options to resolve the issue
    void Button(uint8_t index);
    
    /// Issue an explicit "homing" command into the MMU
    void Home(uint8_t mode);

    /// @returns current state of FINDA (true=filament present, false=filament not present)
    inline bool FindaDetectsFilament()const { return logic.FindaPressed(); }

    /// @returns Current error code
    inline ErrorCode MMUCurrentErrorCode() const { return logic.Error(); }

    /// @returns the version of the connected MMU FW.
    /// In the future we'll return the trully detected FW version
    Version GetMMUFWVersion()const {
        if( State() == xState::Active ){
            return { logic.MmuFwVersionMajor(), logic.MmuFwVersionMinor(), logic.MmuFwVersionBuild() };
        } else {
            return { 0, 0, 0}; 
        }
    }

    // Helper variable to monitor knob in MMU error screen in blocking functions e.g. manage_response
    bool is_mmu_error_monitor_active;

    /// Method to read-only mmu_print_saved
    bool MMU_PRINT_SAVED() const { return mmu_print_saved != SavedState::None; }

private:
    /// Perform software self-reset of the MMU (sends an X0 command)
    void ResetX0();
    
    /// Trigger reset pin of the MMU
    void TriggerResetPin();
    
    /// Perform power cycle of the MMU (cold boot)
    /// Please note this is a blocking operation (sleeps for some time inside while doing the power cycle)
    void PowerCycle();
    
    /// Stop the communication, but keep the MMU powered on (for scenarios with incorrect FW version)
    void StopKeepPowered();

    /// Along with the mmu_loop method, this loops until a response from the MMU is received and acts upon.
    /// In case of an error, it parks the print head and turns off nozzle heating
    void manage_response(const bool move_axes, const bool turn_off_nozzle);
    
    /// Performs one step of the protocol logic state machine 
    /// and reports progress and errors if needed to attached ExtUIs.
    /// Updates the global state of MMU (Active/Connecting/Stopped) at runtime, see @ref State
    StepStatus LogicStep();
    
    void filament_ramming();
    void execute_extruder_sequence(const E_Step *sequence, uint8_t steps);
    void SetActiveExtruder(uint8_t ex);

    /// Reports an error into attached ExtUIs
    /// @param ec error code, see ErrorCode
    /// @param res reporter error source, is either Printer (0) or MMU (1)
    void ReportError(ErrorCode ec, uint8_t res);

    /// Reports progress of operations into attached ExtUIs
    /// @param pc progress code, see ProgressCode
    void ReportProgress(ProgressCode pc);
    
    /// Responds to a change of MMU's progress
    /// - plans additional steps, e.g. starts the E-motor after fsensor trigger
    void OnMMUProgressMsg(ProgressCode pc);
    
    /// Report the msg into the general logging subsystem (through Marlin's SERIAL_ECHO stuff)
    void LogErrorEvent(const char *msg);
    
    /// Report the msg into the general logging subsystem (through Marlin's SERIAL_ECHO stuff)
    void LogEchoEvent(const char *msg);

    /// Save print and park the print head
    void SaveAndPark(bool move_axes, bool turn_off_nozzle);

    /// Resume hotend temperature, if it was cooled. Safe to call if we aren't saved.
    void ResumeHotendTemp();

    /// Resume position, if the extruder was parked. Safe to all if state was not saved.
    void ResumeUnpark();

    /// Check for any button/user input coming from the printer's UI
    void CheckUserInput();
    
    /// Entry check of all external commands.
    /// It can wait until the MMU becomes ready.
    /// Optionally, it can also emit/display an error screen and the user can decide what to do next.
    /// @returns false if the MMU is not ready to perform the command (for whatever reason)
    bool WaitForMMUReady();
    
    ProtocolLogic logic; ///< implementation of the protocol logic layer
    int extruder; ///< currently active slot in the MMU ... somewhat... not sure where to get it from yet
    uint8_t previous_extruder; ///< last active slot in the MMU, useful for M600
    uint8_t tool_change_extruder; ///< only used for UI purposes

    xyz_pos_t resume_position;
    int16_t resume_hotend_temp;
    
    ProgressCode lastProgressCode = ProgressCode::OK;
    ErrorCode lastErrorCode = ErrorCode::MMU_NOT_RESPONDING;
    Buttons lastButton = Buttons::NoButton;

    StepStatus logicStepLastStatus;
    
    enum xState state;

    uint8_t mmu_print_saved;
    bool loadFilamentStarted;
    
    friend struct LoadingToNozzleRAII;
    /// true in case we are doing the LoadToNozzle operation - that means the filament shall be loaded all the way down to the nozzle
    /// unlike the mid-print ToolChange commands, which only load the first ~30mm and then the G-code takes over.
    bool loadingToNozzle;
    
    
};

/// following Marlin's way of doing stuff - one and only instance of MMU implementation in the code base
/// + avoiding buggy singletons on the AVR platform
extern MMU2 mmu2;

} // namespace MMU2
