# # ==========================================================
# # test_watcher.py
# # Test MongoDB watcher behavior
# # Ensures watcher processes data and forwards metrics
# # ==========================================================

# import pytest
# from monitoring.monitor import watch_database

# @pytest.mark.asyncio
# async def test_watcher_calls_evaluate_rules(mocker):
#     """
#     Ensure watch_database processes one MongoDB event and calls evaluate_rules exactly once.
#     """

#     # Mock evaluate_rules
#     mock_eval = mocker.patch("monitoring.monitor.evaluate_rules")

#     # Mock MetricsEngine
#     mocker.patch("monitoring.monitor.MetricsEngine")

#     # Fake MongoDB change event
#     fake_event = {
#         "fullDocument": {
#             "data": {
#                 "blink": {"rawValue": 1},
#                 "rgb": {"r": 10, "g": 20, "b": 5, "clear": 100},
#             }
#         }
#     }

#     # ------------------------------------------------------
#     # Create async generator (one event then stop)
#     # ------------------------------------------------------
#     async def fake_stream_generator():
#         yield fake_event
#         return  # end generator

#     # ------------------------------------------------------
#     # Create fake context manager that returns our generator
#     # ------------------------------------------------------
#     class FakeWatchContext:
#         async def __aenter__(self):
#             return fake_stream_generator()

#         async def __aexit__(self, exc_type, exc, tb):
#             return False

#     # Patch db.raw_readings.watch to return our context manager
#     mocker.patch(
#         "monitoring.monitor.db.raw_readings.watch",
#         return_value=FakeWatchContext()
#     )

#     # ------------------------------------------------------
#     # Run watcher for ONE event by forcing it to exit using timeout
#     # ------------------------------------------------------
#     # asyncio.wait_for stops after 0.1s even if function hangs
#     import asyncio
#     try:
#         await asyncio.wait_for(watch_database(), timeout=0.1)
#     except asyncio.TimeoutError:
#         pass  # Expected: watcher runs forever normally

#     # Ensure evaluate_rules was called ONCE
#     assert mock_eval.await_count == 1
