#!/bin/bash

# Usage: az_get_features.sh > output.json

PROJECT="GN"
TEAM="Team Two Face"

echo "["

FEATURE_IDS=$(az boards query --wiql "
SELECT [System.Id] FROM workitems
WHERE
    [System.TeamProject] = '$PROJECT'
    AND [System.WorkItemType] = 'Feature'
    AND [System.AreaPath] = 'GN\\Applications\\SWART\\$TEAM'
" --query "[].id" -o tsv)

total_features=$(echo "$FEATURE_IDS" | wc -w)
current_feature=0
first_feature=true
feature_id=33011

#for fid in $FEATURE_IDS; do
    current_feature=$((current_feature+1))
    fid=$feature_id
    echo "Processing Feature $current_feature of $total_features (ID: $fid)" >&2

    if [ "$first_feature" = false ]; then
        echo ","
    fi
    first_feature=false

    FEATURE_JSON=$(az boards work-item show --id "$fid" -o json)

    FEATURE_TITLE=$(jq -r '.fields["System.Title"]' <<< "$FEATURE_JSON")
    FEATURE_DESC_HTML=$(jq -r '.fields["System.Description"] // ""' <<< "$FEATURE_JSON")
    FEATURE_AC_HTML=$(jq -r '.fields["GNR.AcceptanceCriteria"] // ""' <<< "$FEATURE_JSON")

    FEATURE_DESC=$(echo "$FEATURE_DESC_HTML" | pandoc -f html -t plain)
    FEATURE_AC=$(echo "$FEATURE_AC_HTML" | pandoc -f html -t plain)

    echo -n "  {\"id\": $fid, \"name\": $(jq -Rs . <<<"$FEATURE_TITLE"), \"description\": $(jq -Rs . <<<"$FEATURE_DESC"), \"acceptanceCriteria\": $(jq -Rs . <<<"$FEATURE_AC"), \"stories\": ["

    STORY_IDS=$(az boards query --wiql "
    SELECT [System.Id] FROM workitems
    WHERE
        [System.TeamProject] = '$PROJECT'
        AND [System.WorkItemType] = 'User Story'
        AND [System.Parent] = $fid
    " --query "[].id" -o tsv)

    first_story=true
    total_stories=$(echo "$STORY_IDS" | wc -w)
    current_story=0

    for sid in $STORY_IDS; do
        current_story=$((current_story+1))
        if [ "$first_story" = false ]; then
            echo -n ","
        fi
        first_story=false

        STORY_JSON=$(az boards work-item show --id "$sid" -o json)

        STORY_TITLE=$(jq -r '.fields["System.Title"]' <<< "$STORY_JSON")
        STORY_DESC_HTML=$(jq -r '.fields["System.Description"] // ""' <<< "$STORY_JSON")
        STORY_AC_HTML=$(jq -r '.fields["Microsoft.VSTS.Common.AcceptanceCriteria"] // ""' <<< "$STORY_JSON")
        STORY_TAGS_RAW=$(jq -r '.fields["System.Tags"] // ""' <<< "$STORY_JSON")

        STORY_DESC=$(echo "$STORY_DESC_HTML" | pandoc -f html -t plain)
        STORY_AC=$(echo "$STORY_AC_HTML" | pandoc -f html -t plain)

        if [[ -z "$STORY_TAGS_RAW" ]]; then
            STORY_TAGS_JSON="[]"
        else
            STORY_TAGS_JSON=$(jq -Rc 'split(";") | map(gsub("^ +| +$";""))' <<< "$STORY_TAGS_RAW")
        fi

        echo -n "{\"id\": $sid, \"name\": $(jq -Rs . <<<"$STORY_TITLE"), \"description\": $(jq -Rs . <<<"$STORY_DESC"), \"acceptanceCriteria\": $(jq -Rs . <<<"$STORY_AC"), \"tags\": $STORY_TAGS_JSON}"
    done

    echo -n "]}"
#done

echo
echo "]"
