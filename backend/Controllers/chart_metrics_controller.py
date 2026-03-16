from fastapi import HTTPException
from database import db
from datetime import datetime, timedelta
from Models.chart_metrics_model import ChartMetricsModel


# Add new chart metrics record (every 5 minutes)
async def create_chart_metric(metric: ChartMetricsModel):

    if hasattr(metric, "dict"):
        metric_dict = metric.dict()
    else:
        metric_dict = metric

    now = datetime.utcnow()

    metric_dict["created_at"] = now
    metric_dict["updated_at"] = now

    # if timestamp is not provided, use current time
    if not metric_dict.get("timestamp"):
        metric_dict["timestamp"] = now

    # save to DB
    result = await db.chart_metrics.insert_one(metric_dict)

    if not result.inserted_id:
        raise HTTPException(status_code=500, detail="Error inserting chart metrics")

    metric_dict["id"] = str(result.inserted_id)

    return {
        "success": True,
        "id": str(result.inserted_id),
        "message": "Chart metric created successfully"
    }
    

# ---------------------------------------------------------
# Helper: parse selected date from query param
# ---------------------------------------------------------
def parse_selected_date(selected_date: str | None = None) -> datetime | None:
    if not selected_date:
        return None

    try:
        return datetime.strptime(selected_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid selected_date format. Use YYYY-MM-DD."
        )



# ---------------------------------------------------------
# Helper: build date filter based on range
# supported ranges:
# - day
# - week
# - month
# - year
# ---------------------------------------------------------
def build_date_filter(range_type: str, selected_date: datetime | None = None):
    now = datetime.utcnow()

    # if no selected date is provided, use current date/time
    base_date = selected_date or now

    if range_type == "day":
        # start of the selected day
        start_date = datetime(base_date.year, base_date.month, base_date.day)
        end_date = start_date + timedelta(days=1)

    elif range_type == "week":
        # get beginning of the week (Monday)
        start_date = datetime(base_date.year, base_date.month, base_date.day) - timedelta(days=base_date.weekday())
        end_date = start_date + timedelta(days=7)

    elif range_type == "month":
        # start of selected month
        start_date = datetime(base_date.year, base_date.month, 1)

        # next month
        if base_date.month == 12:
            end_date = datetime(base_date.year + 1, 1, 1)
        else:
            end_date = datetime(base_date.year, base_date.month + 1, 1)

    elif range_type == "year":
        # start of selected year
        start_date = datetime(base_date.year, 1, 1)
        end_date = datetime(base_date.year + 1, 1, 1)

    else:
        raise HTTPException(status_code=400, detail="Invalid range. Use day, week, month, or year.")

    return start_date, end_date


# ---------------------------------------------------------
# Helper: build MongoDB group format based on range
# day   -> group by hour
# week  -> group by day
# month -> group by day
# year  -> group by month
# ---------------------------------------------------------
def build_group_id(range_type: str):
    if range_type == "day":
        return {
            "year": {"$year": "$timestamp"},
            "month": {"$month": "$timestamp"},
            "day": {"$dayOfMonth": "$timestamp"},
            "hour": {"$hour": "$timestamp"},
        }

    elif range_type in ["week", "month"]:
        return {
            "year": {"$year": "$timestamp"},
            "month": {"$month": "$timestamp"},
            "day": {"$dayOfMonth": "$timestamp"},
        }

    elif range_type == "year":
        return {
            "year": {"$year": "$timestamp"},
            "month": {"$month": "$timestamp"},
        }

    raise HTTPException(status_code=400, detail="Invalid range. Use day, week, month, or year.")


# ---------------------------------------------------------
# Helper: format label for chart response
# ---------------------------------------------------------
def format_label(range_type: str, group_id: dict):
    if range_type == "day":
        hour = group_id["hour"]
        hour_12 = hour % 12
        if hour_12 == 0:
            hour_12 = 12
        suffix = "AM" if hour < 12 else "PM"
        return f"{hour_12} {suffix}"

    elif range_type in ["week", "month"]:
        return f"{group_id['day']}/{group_id['month']}"

    elif range_type == "year":
        month_names = {
            1: "Jan", 2: "Feb", 3: "Mar", 4: "Apr",
            5: "May", 6: "Jun", 7: "Jul", 8: "Aug",
            9: "Sep", 10: "Oct", 11: "Nov", 12: "Dec"
        }
        return month_names.get(group_id["month"], str(group_id["month"]))

    return "Unknown"

# ---------------------------------------------------------
# Helper: format label for 3-hour buckets in day range
# ---------------------------------------------------------
def format_3hour_bucket_label(bucket_index: int):
    start_hour = bucket_index * 3
    end_hour = start_hour + 3

    def to_12h(hour: int):
        suffix = "AM" if hour < 12 or hour == 24 else "PM"
        hour_12 = hour % 12
        if hour_12 == 0:
            hour_12 = 12
        return f"{hour_12} {suffix}"

    start_label = to_12h(start_hour)
    end_label = to_12h(end_hour if end_hour < 24 else 24)

    return f"{start_label} - {end_label}"

    

# ---------------------------------------------------------
# Get Blink by Time chart data (for day range only)
# Returns average blink_rate for 3-hour buckets in a day
# --------------------------------------------------------- 
async def get_blink_by_time(user_id: str, form_id: str, selected_date: datetime | None = None):
    start_date, end_date = build_date_filter("day", selected_date)

    pipeline = [
        {
            "$match": {
                "user_id": user_id,
                "form_id": form_id,
                "timestamp": {"$gte": start_date, "$lt": end_date},
            }
        },
        {
            "$group": {
                "_id": {
                    "bucket": {
                        "$floor": {
                            "$divide": [{"$hour": "$timestamp"}, 3]
                        }
                    }
                },
                "avg_value": {"$avg": "$blink_rate"},
            }
        },
        {
            "$sort": {"_id.bucket": 1}
        }
    ]

    bucket_map = {i: 0.0 for i in range(8)}

    async for doc in db.chart_metrics.aggregate(pipeline):
        bucket_index = doc["_id"]["bucket"]
        bucket_map[bucket_index] = round(doc["avg_value"], 2) if doc["avg_value"] is not None else 0.0

    results = []
    for i in range(8):
        results.append({
            "label": format_3hour_bucket_label(i),
            "value": bucket_map[i]
        })

    return {
        "chart": "blink_by_time",
        "range": "day",
        "selected_date": selected_date.strftime("%Y-%m-%d") if selected_date else None,
        "data": results
    }


# ---------------------------------------------------------
# Get Blue Light Scatter chart data
# X = avg lux
# Y = avg blue_ratio
# label = time bucket label
# ---------------------------------------------------------
async def get_blue_light_scatter(user_id: str, form_id: str, range_type: str, selected_date: datetime | None = None):
    start_date, end_date = build_date_filter(range_type, selected_date)
    group_id = build_group_id(range_type)

    pipeline = [
        {
            "$match": {
                "user_id": user_id,
                "form_id": form_id,
                "timestamp": {"$gte": start_date, "$lt": end_date},
            }
        },
        {
            "$group": {
                "_id": group_id,
                "avg_lux": {"$avg": "$lux"},
                "avg_blue_ratio": {"$avg": "$blue_ratio"},
            }
        },
        {
            "$sort": {"_id.year": 1, "_id.month": 1, "_id.day": 1, "_id.hour": 1}
        }
    ]

    results = []
    async for doc in db.chart_metrics.aggregate(pipeline):
        results.append({
            "x": round(doc["avg_lux"], 2) if doc["avg_lux"] is not None else 0.0,
            "y": round(doc["avg_blue_ratio"], 4) if doc["avg_blue_ratio"] is not None else 0.0,
            "label": format_label(range_type, doc["_id"]),
        })

    return {
        "chart": "blue_light_scatter",
        "range": range_type,
        "selected_date": selected_date.strftime("%Y-%m-%d") if selected_date else None,
        "data": results
    }