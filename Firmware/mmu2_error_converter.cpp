#include "mmu2_error_converter.h"
#include "mmu2/error_codes.h"
#include "mmu2/errors_list.h"
#include "language.h"
#include <stdio.h>

namespace MMU2 {

// we don't have a constexpr find_if in C++17/STL yet
template <class InputIt, class UnaryPredicate>
constexpr InputIt find_if_cx(InputIt first, InputIt last, UnaryPredicate p) {
    for (; first != last; ++first) {
        if (p(*first)) {
            return first;
        }
    }
    return last;
}

// Making a constexpr FindError should instruct the compiler to optimize the ConvertMMUErrorCode
// in such a way that no searching will ever be done at runtime.
// A call to FindError then compiles to a single instruction even on the AVR.
static constexpr uint16_t FindErrorIndex(uint32_t pec) {
    constexpr uint32_t errorCodesSize = sizeof(errorCodes) / sizeof(errorCodes[0]);
    constexpr auto errorCodesEnd = errorCodes + errorCodesSize;
    auto i = find_if_cx(errorCodes, errorCodesEnd, [pec](uint16_t ed) -> bool {
        return ed == pec;
    });
    return i != errorCodesEnd ? *i : errorCodes[errorCodesSize - 1];
}

const uint16_t MMUErrorCodeIndex(uint16_t ec) {
    switch (ec) {
    case (uint16_t)ErrorCode::FINDA_DIDNT_SWITCH_ON:
        return FindErrorIndex(ERR_MECHANICAL_FINDA_DIDNT_TRIGGER);
    case (uint16_t)ErrorCode::FINDA_DIDNT_SWITCH_OFF:
        return FindErrorIndex(ERR_MECHANICAL_FINDA_DIDNT_GO_OFF);
    case (uint16_t)ErrorCode::FSENSOR_DIDNT_SWITCH_ON:
        return FindErrorIndex(ERR_MECHANICAL_FSENSOR_DIDNT_TRIGGER);
    case (uint16_t)ErrorCode::FSENSOR_DIDNT_SWITCH_OFF:
        return FindErrorIndex(ERR_MECHANICAL_FSENSOR_DIDNT_GO_OFF);
    case (uint16_t)ErrorCode::STALLED_PULLEY:
    case (uint16_t)ErrorCode::MOVE_PULLEY_FAILED:
        return FindErrorIndex(ERR_MECHANICAL_PULLEY_CANNOT_MOVE);
    case (uint16_t)ErrorCode::HOMING_SELECTOR_FAILED:
        return FindErrorIndex(ERR_MECHANICAL_SELECTOR_CANNOT_HOME);
    case (uint16_t)ErrorCode::MOVE_SELECTOR_FAILED:
        return FindErrorIndex(ERR_MECHANICAL_SELECTOR_CANNOT_MOVE);
    case (uint16_t)ErrorCode::HOMING_IDLER_FAILED:
        return FindErrorIndex(ERR_MECHANICAL_IDLER_CANNOT_HOME);
    case (uint16_t)ErrorCode::MMU_NOT_RESPONDING:
        return FindErrorIndex(ERR_MECHANICAL_IDLER_CANNOT_MOVE);
    case (uint16_t)ErrorCode::PROTOCOL_ERROR:
        return FindErrorIndex(ERR_CONNECT_COMMUNICATION_ERROR);
    case (uint16_t)ErrorCode::FILAMENT_ALREADY_LOADED:
        return FindErrorIndex(ERR_SYSTEM_FILAMENT_ALREADY_LOADED);
    case (uint16_t)ErrorCode::INVALID_TOOL:
        return FindErrorIndex(ERR_SYSTEM_INVALID_TOOL);
    case (uint16_t)ErrorCode::QUEUE_FULL:
        return FindErrorIndex(ERR_SYSTEM_QUEUE_FULL);
    case (uint16_t)ErrorCode::VERSION_MISMATCH:
        return FindErrorIndex(ERR_SYSTEM_FW_UPDATE_NEEDED);
    case (uint16_t)ErrorCode::INTERNAL:
        return FindErrorIndex(ERR_SYSTEM_FW_RUNTIME_ERROR);
    case (uint16_t)ErrorCode::FINDA_VS_EEPROM_DISREPANCY:
        return FindErrorIndex(ERR_SYSTEM_UNLOAD_MANUALLY);
    }

//    // TMC-related errors - multiple of these can occur at once
//    // - in such a case we report the first which gets found/converted into Prusa-Error-Codes (usually the fact, that one TMC has an issue is serious enough)
//    // By carefully ordering the checks here we can prioritize the errors being reported to the user.
    if (ec & (uint16_t)ErrorCode::TMC_PULLEY_BIT) {
        if (ec & (uint16_t)ErrorCode::TMC_IOIN_MISMATCH)
            return FindErrorIndex(ERR_ELECTRICAL_PULLEY_TMC_DRIVER_ERROR);
        if (ec & (uint16_t)ErrorCode::TMC_RESET)
            return FindErrorIndex(ERR_ELECTRICAL_PULLEY_TMC_DRIVER_RESET);
        if (ec & (uint16_t)ErrorCode::TMC_UNDERVOLTAGE_ON_CHARGE_PUMP)
            return FindErrorIndex(ERR_ELECTRICAL_PULLEY_TMC_UNDERVOLTAGE_ERROR);
        if (ec & (uint16_t)ErrorCode::TMC_SHORT_TO_GROUND)
            return FindErrorIndex(ERR_ELECTRICAL_PULLEY_TMC_DRIVER_SHORTED);
        if (ec & (uint16_t)ErrorCode::TMC_OVER_TEMPERATURE_WARN)
            return FindErrorIndex(ERR_TEMPERATURE_PULLEY_WARNING_TMC_TOO_HOT);
        if (ec & (uint16_t)ErrorCode::TMC_OVER_TEMPERATURE_ERROR)
            return FindErrorIndex(ERR_TEMPERATURE_PULLEY_TMC_OVERHEAT_ERROR);
    } else if (ec & (uint16_t)ErrorCode::TMC_SELECTOR_BIT) {
        if (ec & (uint16_t)ErrorCode::TMC_IOIN_MISMATCH)
            return FindErrorIndex(ERR_ELECTRICAL_SELECTOR_TMC_DRIVER_ERROR);
        if (ec & (uint16_t)ErrorCode::TMC_RESET)
            return FindErrorIndex(ERR_ELECTRICAL_SELECTOR_TMC_DRIVER_RESET);
        if (ec & (uint16_t)ErrorCode::TMC_UNDERVOLTAGE_ON_CHARGE_PUMP)
            return FindErrorIndex(ERR_ELECTRICAL_SELECTOR_TMC_UNDERVOLTAGE_ERROR);
        if (ec & (uint16_t)ErrorCode::TMC_SHORT_TO_GROUND)
            return FindErrorIndex(ERR_ELECTRICAL_SELECTOR_TMC_DRIVER_SHORTED);
        if (ec & (uint16_t)ErrorCode::TMC_OVER_TEMPERATURE_WARN)
            return FindErrorIndex(ERR_TEMPERATURE_SELECTOR_WARNING_TMC_TOO_HOT);
        if (ec & (uint16_t)ErrorCode::TMC_OVER_TEMPERATURE_ERROR)
            return FindErrorIndex(ERR_TEMPERATURE_SELECTOR_TMC_OVERHEAT_ERROR);
    } else if (ec & (uint16_t)ErrorCode::TMC_IDLER_BIT) {
        if (ec & (uint16_t)ErrorCode::TMC_IOIN_MISMATCH)
            return FindErrorIndex(ERR_ELECTRICAL_IDLER_TMC_DRIVER_ERROR);
        if (ec & (uint16_t)ErrorCode::TMC_RESET)
            return FindErrorIndex(ERR_ELECTRICAL_IDLER_TMC_DRIVER_RESET);
        if (ec & (uint16_t)ErrorCode::TMC_UNDERVOLTAGE_ON_CHARGE_PUMP)
            return FindErrorIndex(ERR_ELECTRICAL_IDLER_TMC_UNDERVOLTAGE_ERROR);
        if (ec & (uint16_t)ErrorCode::TMC_SHORT_TO_GROUND)
            return FindErrorIndex(ERR_ELECTRICAL_IDLER_TMC_DRIVER_SHORTED);
        if (ec & (uint16_t)ErrorCode::TMC_OVER_TEMPERATURE_WARN)
            return FindErrorIndex(ERR_TEMPERATURE_IDLER_WARNING_TMC_TOO_HOT);
        if (ec & (uint16_t)ErrorCode::TMC_OVER_TEMPERATURE_ERROR)
            return FindErrorIndex(ERR_TEMPERATURE_IDLER_TMC_OVERHEAT_ERROR);
    }

//    // if nothing got caught, return a generic error
//    return FindError(ERR_OTHER);
}

void TranslateErr(uint16_t ec, char *dst, size_t dstSize) { 
    uint16_t ei = MMUErrorCodeIndex(ec);
    // just to prevent the compiler from stripping the data structures from the final binary for now
    *dst = errorButtons[ei];
    snprintf(
        dst, dstSize, "%S %S",
        static_cast<const char * const>(pgm_read_ptr(&errorTitles[ei])),
        static_cast<const char * const>(pgm_read_ptr(&errorDescs[ei]))
    );
}

} // namespace MMU2
