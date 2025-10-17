from flask import Flask, request, jsonify
from flask_restful import Resource, Api
from werkzeug.exceptions import HTTPException, BadRequest
from functools import wraps
from prometheus_flask_exporter import PrometheusMetrics

app = Flask(__name__)
api = Api(app)
metrics = PrometheusMetrics(app)

# In-memory "database"
employees = {
    1: {"name": "Mahesh", "role": "Engineer", "salary": 150000},
    2: {"name": "Hari", "role": "Manager", "salary": 200000},
}


# ---- Security: Input Validation ----
def validate_employee_data(data, require_all=True):
    """Validate incoming employee data"""
    if not isinstance(data, dict):
        raise BadRequest("Invalid JSON payload")

    required_fields = {"name": str, "role": str, "salary": int}
    for field, field_type in required_fields.items():
        if require_all and field not in data:
            raise BadRequest(f"Missing field: {field}")
        if field in data and not isinstance(data[field], field_type):
            raise BadRequest(
                f"Invalid type for {field}, expected {field_type.__name__}"
            )

    return True


# ---- Security: Error handler ----
@app.errorhandler(Exception)
def handle_exception(e):
    """Generic error handler with no stack trace leaks"""
    if isinstance(e, HTTPException):
        return jsonify(error=str(e)), e.code
    return jsonify(error="Internal server error"), 500


# ---- Security: Response headers ----
@app.after_request
def set_secure_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    return response


# ---- Rate limiting / request size limiting ----
@app.before_request
def limit_request_size():
    max_size = 1 * 1024 * 1024  # 1 MB
    if request.content_length is not None and request.content_length > max_size:
        return jsonify(error="Request too large"), 413


# ---- Resources ----
class EmployeeList(Resource):
    def get(self):
        # For demo, return all employees without salaries
        sanitized = {
            k: {"name": v["name"], "role": v["role"]} for k, v in employees.items()
        }
        return jsonify(sanitized)

    def post(self):
        data = request.get_json(force=True, silent=True)
        validate_employee_data(data, require_all=True)
        new_id = max(employees.keys()) + 1 if employees else 1
        employees[new_id] = {
            "name": data["name"],
            "role": data["role"],
            "salary": data["salary"],
        }
        return {new_id: {"name": data["name"], "role": data["role"]}}, 201


class Employee(Resource):
    def get(self, emp_id):
        if emp_id in employees:
            emp = employees[emp_id].copy()
            emp.pop("salary")  # Don’t expose sensitive info
            return emp
        return {"error": "Employee not found"}, 404

    def put(self, emp_id):
        if emp_id in employees:
            data = request.get_json(force=True, silent=True)
            validate_employee_data(data, require_all=False)
            employees[emp_id].update(data)
            return {
                "name": employees[emp_id]["name"],
                "role": employees[emp_id]["role"],
            }
        return {"error": "Employee not found"}, 404

    def delete(self, emp_id):
        if emp_id in employees:
            deleted = employees.pop(emp_id)
            return {"deleted": {"name": deleted["name"], "role": deleted["role"]}}
        return {"error": "Employee not found"}, 404


api.add_resource(EmployeeList, "/employees")
api.add_resource(Employee, "/employees/<int:emp_id>")


# ---- Health / Readiness ----
@app.route("/health")
def health():
    return jsonify(status="alive"), 200


@app.route("/ready")
def readiness():
    # Could add DB/cache checks here
    return jsonify(status="ready"), 200


if __name__ == "__main__":
    # Debug disabled for production
    app.run(host="0.0.0.0", port=5500, debug=False)
