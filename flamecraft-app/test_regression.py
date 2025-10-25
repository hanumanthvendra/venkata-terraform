import pytest
import requests
import json
import os

# Configuration: Service URL (internal cluster DNS or IP)
# In Kubernetes, use service name: http://flamecraft-app.dev.svc.cluster.local:5500
# For local testing, set BASE_URL to localhost:5500
BASE_URL = os.getenv('FLAMECRAFT_SERVICE_URL', 'http://flamecraft-app.dev.svc.cluster.local:5500')

class TestFlamecraftRegression:
    """Regression test suite for Flamecraft Flask API"""

    def setup_method(self):
        """Setup before each test"""
        self.base_url = BASE_URL.rstrip('/')
        # Reset test data if possible (assuming in-memory, but for regression, test existing state)
        pass

    def test_health_endpoint(self):
        """Test /health endpoint"""
        response = requests.get(f"{self.base_url}/health", timeout=10)
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'alive'

    def test_readiness_endpoint(self):
        """Test /ready endpoint"""
        response = requests.get(f"{self.base_url}/ready", timeout=10)
        assert response.status_code == 200
        data = response.json()
        assert data['status'] == 'ready'

    def test_get_employees(self):
        """Test GET /employees - should return sanitized data"""
        response = requests.get(f"{self.base_url}/employees", timeout=10)
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, dict)
        # Check structure (assuming initial data exists)
        if data:
            for emp_id, emp in data.items():
                assert 'name' in emp
                assert 'role' in emp
                assert 'salary' not in emp  # Salary should be hidden

    def test_get_employee_by_id(self):
        """Test GET /employees/<id>"""
        # Assuming employee 1 exists
        response = requests.get(f"{self.base_url}/employees/1", timeout=10)
        if response.status_code == 200:
            data = response.json()
            assert 'name' in data
            assert 'role' in data
            assert 'salary' not in data
        else:
            assert response.status_code == 404

    def test_post_employee(self):
        """Test POST /employees - create new employee"""
        new_employee = {
            "name": "Test User",
            "role": "Tester",
            "salary": 100000
        }
        response = requests.post(
            f"{self.base_url}/employees",
            json=new_employee,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        assert response.status_code == 201
        data = response.json()
        # Should return the new ID with name and role
        assert isinstance(data, dict)
        emp_id = list(data.keys())[0]
        assert data[emp_id]['name'] == 'Test User'
        assert data[emp_id]['role'] == 'Tester'

    def test_put_employee(self):
        """Test PUT /employees/<id> - update employee"""
        # First, create an employee to update
        new_employee = {
            "name": "Update Test",
            "role": "Intern",
            "salary": 50000
        }
        post_response = requests.post(
            f"{self.base_url}/employees",
            json=new_employee,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        assert post_response.status_code == 201
        emp_id = list(post_response.json().keys())[0]

        # Now update
        update_data = {
            "name": "Updated Test",
            "role": "Senior Intern"
        }
        put_response = requests.put(
            f"{self.base_url}/employees/{emp_id}",
            json=update_data,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        assert put_response.status_code == 200
        data = put_response.json()
        assert data['name'] == 'Updated Test'
        assert data['role'] == 'Senior Intern'

    def test_delete_employee(self):
        """Test DELETE /employees/<id>"""
        # Create employee to delete
        new_employee = {
            "name": "Delete Test",
            "role": "Temp",
            "salary": 30000
        }
        post_response = requests.post(
            f"{self.base_url}/employees",
            json=new_employee,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        assert post_response.status_code == 201
        emp_id = list(post_response.json().keys())[0]

        # Delete
        delete_response = requests.delete(f"{self.base_url}/employees/{emp_id}", timeout=10)
        assert delete_response.status_code == 200
        data = delete_response.json()
        assert data['deleted']['name'] == 'Delete Test'

        # Verify deletion
        get_response = requests.get(f"{self.base_url}/employees/{emp_id}", timeout=10)
        assert get_response.status_code == 404

    def test_invalid_employee_post(self):
        """Test POST with invalid data"""
        invalid_data = {"name": "Test", "role": 123}  # Invalid type
        response = requests.post(
            f"{self.base_url}/employees",
            json=invalid_data,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        assert response.status_code == 400

    def test_large_request_size(self):
        """Test request size limiting"""
        large_data = {"name": "A" * (2 * 1024 * 1024), "role": "Test", "salary": 100000}
        response = requests.post(
            f"{self.base_url}/employees",
            json=large_data,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        assert response.status_code == 413  # Request too large

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
