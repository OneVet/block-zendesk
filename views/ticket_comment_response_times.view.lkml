view: ticket_comment_response_times {
  derived_table: {
    explore_source: ticket {
      column: created_time { field: ticket_comment.created_raw }
      column: ticket_id { field: ticket.id }
      column: id { field: ticket_comment.id }
      column: body { field: ticket_comment.body }
      column: user_id { field: ticket_comment.user_id }
      column: is_agent { field: ticket_commenter.is_agent }

      derived_column: next_agent_response_time {
        sql:
        CASE WHEN
           CASE WHEN
              LAG(is_agent IS TRUE,1) OVER (
                                            PARTITION BY ticket_id
                                            ORDER BY created_time ASC
                                           ) IS NULL
                 OR
                 (
                     LAG(is_agent IS TRUE,1) OVER (
                                                   PARTITION BY ticket_id
                                                   ORDER BY created_time ASC
                                                  ) IS TRUE
                        AND
                     is_agent IS FALSE
                 )
             THEN
                 1
             ELSE
                 0
           END = 1
        THEN
            -- Can replace the first_value input with a "is_suppport_agent" flag after building DT
            FIRST_VALUE( CASE WHEN is_agent IS TRUE THEN created_time ELSE NULL END )
                OVER (
                      PARTITION BY ticket_id
                      ORDER BY created_time ASC,
                               CASE WHEN is_agent THEN 1 ELSE 0 END DESC
                      ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
                     )
        ELSE
            NULL
        END ;;
      }
      derived_column: responding_agent_id {
        sql:
CASE WHEN
		CASE WHEN
	        LAG(is_agent IS TRUE,1) OVER (
				                         PARTITION BY ticket_id
				                         ORDER BY created_time ASC
			                        ) IS NULL
               OR
	        (
				LAG(is_agent IS TRUE,1) OVER (
					                          PARTITION BY ticket_id
					                          ORDER BY created_time ASC
				                        ) IS TRUE
				   AND
				is_agent IS FALSE
			)
         THEN
	          1
         ELSE
	          0
         END = 1
	 THEN
                 -- Can replace the first_value input with a "is_suppport_agent" flag after building DT
                 FIRST_VALUE(CASE WHEN is_agent THEN user_id ELSE NULL END)
	                              OVER (
									  PARTITION BY ticket_id
									  ORDER BY created_time ASC,
									           CASE WHEN is_agent THEN 1 ELSE 0 END  DESC
									  ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
								  )
	 ELSE
	       NULL
	 END
         ;;
      }
      derived_column: first_response {
        sql: CASE WHEN ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY created_time ASC) = 1 THEN TRUE ELSE FALSE END ;;
      }

      filters: {
        field: ticket_comment.public
        value: "Yes"
      }
    }
  }
  dimension_group: created {
    type: time
    sql: ${TABLE}.created_time ;;
  }
  dimension: ticket_id {
    type: number
  }
  dimension: id {
    type: number
    primary_key: yes
  }
  dimension: body {}
  dimension: user_id {
    type: number
  }
  dimension: is_agent {
    label: "Ticket Commenter Is Agent (Yes / No)"
    type: yesno
  }

  dimension_group: next_agent_response {
    type: time
    sql: ${TABLE}.next_agent_response_time ;;
  }

  dimension_group: to_respond {
    type: duration
    intervals: [hour]
    sql_start: ${created_raw} ;;
    sql_end: ${next_agent_response_raw} ;;
  }
  # Needs refactoring, for now, we'll use the straight difference in timestamps
  dimension: response_time {
    label: "In Hours (includes weekends by default)"
    type: number
    sql:  ${hours_to_respond};;
  }

  dimension: responding_agent_id {
    type: number
    html: {{ value }} ;;
  }

  measure: average_response_time {
    type: average
    sql: ${response_time} ;;
    value_format_name: decimal_2
    drill_fields: [response_detail*]
  }

  measure: median_response_time {
    type: median
    sql: ${response_time} ;;
    value_format_name: decimal_2
    drill_fields: [response_detail*]
  }

  set: response_detail {
    fields: [id, ticket_id, created_date, response_time, is_agent, user.name, user.email]
  }
}
