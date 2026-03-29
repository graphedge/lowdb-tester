#!/bin/bash
# Vibe templates for SpecFarm

get_nudge() {
    local vibe=$1
    local adherence=$2
    
    case "$vibe" in
        farm)
            if [[ "$adherence" -lt 80 ]]; then
                echo "Grumpy Farmer: Your fields are full of weeds! Get to work."
            elif [[ "$adherence" -lt 100 ]]; then
                echo "Encouraging Farmer: A little more care and your crops will thrive."
            else
                echo "Happy Farmer: The harvest looks bountiful this season!"
            fi
            ;;
        jungle)
            if [[ "$adherence" -lt 80 ]]; then
                echo "Jaguar: Watch your step. The vines are tangling your code."
            elif [[ "$adherence" -lt 100 ]]; then
                echo "Monkey: Swinging through the branches... keep climbing!"
            else
                echo "Lion: You are the king of the jungle. Roar!"
            fi
            ;;
        strict)
            if [[ "$adherence" -lt 80 ]]; then
                echo "ERROR: Compliance is below threshold. Violations must be addressed immediately."
            elif [[ "$adherence" -lt 100 ]]; then
                echo "WARNING: Minor violations detected. Review and resolve."
            else
                echo "PASS: Full compliance achieved."
            fi
            ;;
        chill)
            if [[ "$adherence" -lt 80 ]]; then
                echo "Hey, let's work together to clean this up — no rush, but it matters."
            elif [[ "$adherence" -lt 100 ]]; then
                echo "Almost there, just a few things to tidy up."
            else
                echo "Great job — everything is looking perfectly clean!"
            fi
            ;;
        corporate)
            if [[ "$adherence" -lt 80 ]]; then
                echo "ACTION REQUIRED: Compliance gaps have been identified. Immediate remediation is required."
            elif [[ "$adherence" -lt 100 ]]; then
                echo "ADVISORY: Minor compliance gaps noted. Please review at your earliest convenience."
            else
                echo "COMPLIANCE VERIFIED: All standards have been met. No action required."
            fi
            ;;
        sarcastic)
            if [[ "$adherence" -lt 80 ]]; then
                echo "Oh wonderful, more violations. Totally expected at this point."
            elif [[ "$adherence" -lt 100 ]]; then
                echo "Shockingly close to compliant. Almost impressive, really."
            else
                echo "Impressive — actually fully compliant. Didn't think we'd see the day."
            fi
            ;;
        plain|*)
            if [[ "$adherence" -lt 80 ]]; then
                echo "Drift is high. Please address violations."
            elif [[ "$adherence" -lt 100 ]]; then
                echo "Drift is low. Almost there."
            else
                echo "System is in full compliance."
            fi
            ;;
    esac
}

