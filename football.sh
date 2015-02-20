#!/bin/bash
#Ajinkya Kale


clean_up(){
rm -f formated_schedule
rm -f temp_file_1
rm -f American_conference
rm -f National_conference
rm -f American_conference_line_wise
rm -f National_conference_line_wise
rm -f final_output
rm -f final_file
}



trap "echo SIGINT; clean_up; exit 2" SIGINT		# deletes all the temproray files after INT interrupt is recived
trap "echo SIGQUIT; clean_up; exit 3" SIGQUIT		# deletes all the temproray files after QUIT interrupt is recived
trap "echo SIGTERM; clean_up; exit 4" SIGTERM		# deletes all all temproray files after TERM interrupt is recived

YEAR=$1

if [ $# -eq 0 ]		# Condition check for no arguments
then
	echo "usage: No argumnets"
	exit 2
fi

if [ $1 -gt 2014 ]	# condition check for future year
then
	echo "usage: year is in future "
	exit 3	
fi


YEAR_oF_SCHEDULE=`expr $YEAR - 1`	# stores the previous year

standings_file="standings."$YEAR_oF_SCHEDULE".downloads"

if [ ! -e "$standings_file" ]
then
	wget -q "http://www.nfl.com/standings?category=div&season=$YEAR_oF_SCHEDULE-REG" -O $standings_file #"standings."$YEAR_oF_SCHEDULE".downloads" 	# Gets the schedule
fi

cat $standings_file | tr -d "\n" | tr -d "\t" | tr -d "\r\n" > formated_schedule
cat formated_schedule | sed 's/.*<table[^>]*>\(.*\)<table>.*/\1/'  > temp_file_1	# removing the table body in html file, i.e <table> .... </table>
cat temp_file_1 | sed 's/.*<tbody>\(.*\)<tbody>.*/\1/' > American_conference		# getting the american conference table
cat temp_file_1 | sed 's/.*<tbody>.*<tbody>\(.*\)<\/tbody>.*/\1/' > National_conference	# getting the National conference table
cat American_conference | sed 's/<\/tr>/<\/tr>\n/g' > American_conference_line_wise	# formatting the above generated files using line wise
cat National_conference | sed 's/<\/tr>/<\/tr>\n/g' > National_conference_line_wise

#COUNT=1
# This function extracts the team name and its win loss and ties records.
# This function uses sed, regular expression to remove <tr>, <\tr>, <td><\td> etc.
# The if condation checks for the valid line to be processed
# paste: it is used to formate the output line by line
# The first sed get the name of the team
# The second sed gets the win loss and ties
# each table is passed to this function, i.e American conference and national conference

Extract_Team(){
COUNT=1
while read line
do
	# Checks for the valid line
	if [[ $COUNT -ne 1 && $COUNT -ne 2 && $COUNT -ne 7 && $COUNT -ne 8 && $COUNT -ne 13 && $COUNT -ne 14 && $COUNT -ne 19 && $COUNT -ne 20 && $COUNT -ne 25 ]]
	then	
		paste -d: <(echo $line | sed 's/<tr[^>]*><td[^>]*>[^<]*<a[^>]*>\(.*\)<\/a><\/td>.*<\/tr>/\1/') <(echo $line | sed 's/<tr[^>]*><td[^>]*>[^<]*<a[^>]*>.*<\/a><\/td><td>\([^>]*\)<\/td[^>]*><td>\([^>]*\)<\/td[^>]*><td>\([^>]\)<\/td[^>]*>.*/\1 \2 \3 /') >> final_file
 
		COUNT=$((COUNT+1))
	else
		COUNT=$((COUNT+1))
	fi
done < $1
}

Extract_Team American_conference_line_wise	# calls the extract team function 
Extract_Team National_conference_line_wise

#This function sets up all the variables required.

initializer(){
	COUNTER=2			# used for each team in row in lut
	win=0				# stores the win
	loss=0				# stores the loss
	tie=0				# stores the tie
	Strength_of_Schedule=0		# stores the strength value
	numerator=0				
	denominator=0
	only_wins=0			# used to add all the wins
	only_loss=0			# used to add all the loss
	only_ties=0			# used to add all the ties
	Total_points_gained=0
	tie_quotient=0
	TEAM_UNDER_CONSIDERATION=1
}


# This while loop through the schedule file for 32 times

while read line1

do
	initializer

	TEAM_ACRONYM=`echo "$line1" | cut -f$TEAM_UNDER_CONSIDERATION`

	if [ "$TEAM_ACRONYM" == "JAX" ]
	then 
		TEAM_ACRONYM=JAC
	fi

	if [ "$TEAM_ACRONYM" == "WSH" ]
	then 
		TEAM_ACRONYM=WAS
	fi

	TEAM_FULL_NAME=`grep -w "$TEAM_ACRONYM" LUT | cut -d: -f2`

	while [ $COUNTER -le 18 ]			# This while loops through the rows

	do

		VAR=`echo "$line1" | cut -f$COUNTER`		# gets the team acronoym
	
		if [ "$VAR" == "JAX" ]				# checking special cases for jacksonville jaguars
		then
			VAR=JAC
		fi

		if [ "$VAR" == "@JAX" ]				# checking for home games i.e @
		 then
			VAR=@JAC
		fi

		if [ "$VAR" == "WSH" ]				# checking special cases for washington sea hawks
		 then	
			 VAR=WAS
		fi
		if [ "$VAR" == "@WSH" ]				# checking for home games i.e @
		then	
			VAR=@WAS
		fi
		if [[ ${VAR:0:1} == "@" ]]			# checking if the tag contains @
		then	
			VAR=`echo $VAR | cut -c2-4`		# if yes, it is removed
		fi
		if [ "$VAR" == "BYE" ]				# checking if its a bye
		then	
			COUNTER=$((COUNTER+1))	
			continue
		fi
		
		TEAM_NAME=`grep -w "$VAR" LUT | cut -d: -f2`			# gets the name of the team from the acronym reference using LUT
		score=`grep -w "$TEAM_NAME" final_file | cut -d: -f2`		# gets the score of the corresponding team
		win=`echo $score | cut -d " " -f1`				# gets the number of wins
		loss=`echo $score | cut -d " " -f2`				# gets the number of loss
		tie=`echo $score | cut -d " " -f3`				# gets the number of ties
		tie_quotient=`echo "scale=4; ($tie/2)" | bc`			# calculating COUNT=1 (1/2)*tie
		numerator=$(echo $win + $tie_quotient | bc)			# every tie is half win so, calculating win+(1/2)*tie, and its a numerator
		denominator=`expr $win + $loss + $tie`				# calculating win + loss + tie, that is denominatior
		only_wins=`expr $win + $only_wins`				# total no. of wins of every opponent team in a row
		only_loss=`expr $loss + $only_loss`				# total no. of loss of every opponent team in a row
		only_ties=`expr $tie + $only_ties`				# total no. of ties of every opponent team in a row
		Total_points_gained=$(echo $numerator + $Total_points_gained | bc)	# total points
		Strength_of_Schedule=`echo "scale=3; ($Total_points_gained/256)" | bc`	# SOS
		temp_Strength_of_Schedule=`echo $Strength_of_Schedule | bc`
		#echo $temp_Strength_of_Schedule
		COUNTER=$((COUNTER+1))

	done

#echo "$TEAM_FULL_NAME:" "$temp_Strength_of_Schedule" ":$only_wins-$only_loss-$only_ties" | bc
#echo $temp_Strength_of_Schedule
printf "%-25s%-10s%s\n" "$TEAM_FULL_NAME:" "$temp_Strength_of_Schedule" ":$only_wins-$only_loss-$only_ties" >> final_output
done < "schedule."$YEAR".download"

cat final_output | sort -t: -k2,2nr -k1,1 | tr -d : 		# Sorting the output according to the 2nd field, if equal then 1st feild.
clean_up			# cleaning up the temporary files
